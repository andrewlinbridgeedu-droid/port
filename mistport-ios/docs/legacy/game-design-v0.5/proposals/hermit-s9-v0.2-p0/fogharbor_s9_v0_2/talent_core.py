"""Pure-Python P0 talent-state reference, not a Unity component.

This validates budget, reachability, draft edits, cascading refunds and a TEST
save shape. No talent combat hooks, Unity UI or actual legacy-save adapter exist.
Callers supply authoritative earned points; saved unspent/old rank totals never
create new points. Real storage must backup, validate and commit atomically.
"""
from __future__ import annotations
from copy import deepcopy
from dataclasses import dataclass
from typing import Any, Mapping, Iterable
from validate_s9 import PREREQUISITES

TREES = ('T', 'P', 'S')
NODE_IDS = tuple(f'{tree}{i}' for tree in TREES for i in range(1, 7))
RULES_VERSION = 's9.tree.1'
SCHEMA_VERSION = 2

class TalentError(ValueError):
    pass

def normalise(levels: Mapping[str, int]) -> dict[str, int]:
    if not isinstance(levels, Mapping):
        raise TalentError('ranks_must_be_mapping')
    unknown=set(levels)-set(NODE_IDS)
    if unknown:
        raise TalentError(f'unknown_nodes:{sorted(map(str, unknown))}')
    result={node:levels.get(node,0) for node in NODE_IDS}
    if any(type(v) is not int or not 0<=v<=5 for v in result.values()):
        raise TalentError('rank_must_be_integer_0_to_5')
    return result

def check_budget(earned: int) -> None:
    if type(earned) is not int or not 0<=earned<=30:
        raise TalentError('earned_must_be_integer_0_to_30')

def reachable_prefix(levels: Mapping[str, int],
                     unlocked: Iterable[str] | None=None) -> dict[str, int]:
    target=normalise(levels)
    allowed=set(NODE_IDS if unlocked is None else unlocked)
    result={node:0 for node in NODE_IDS}
    while True:
        progress=False
        for tree in TREES:
            for index in range(6):
                node=f'{tree}{index+1}'
                if node not in allowed or result[node]>=target[node]:
                    continue
                parent, rank, threshold=PREREQUISITES[index]
                if parent is not None and result[f'{tree}{parent+1}']<rank:
                    continue
                other=sum(result[f'{tree}{j}'] for j in range(1,7))-result[node]
                if other<threshold:
                    continue
                result[node]+=1
                progress=True
        if not progress:
            return result

def validate(levels: Mapping[str, int], earned: int,
             unlocked: Iterable[str] | None=None) -> dict[str, int]:
    check_budget(earned)
    target=normalise(levels)
    if sum(target.values())>earned:
        raise TalentError('point_budget_exceeded')
    reachable=reachable_prefix(target,unlocked)
    if reachable!=target:
        blocked={node:target[node]-reachable[node] for node in NODE_IDS
                 if target[node]!=reachable[node]}
        raise TalentError(f'unreachable_or_story_locked:{blocked}')
    return target

def remaining(levels: Mapping[str, int], earned: int) -> int:
    return earned-sum(validate(levels,earned).values())

@dataclass(frozen=True)
class RemovalPreview:
    node_id: str
    draft_revision: int
    refunded: tuple[tuple[str,int], ...]

    @property
    def total_refund(self) -> int:
        return sum(value for _,value in self.refunded)

class TalentSession:
    """Edits only a draft; applying is a state operation, not a disk write."""
    def __init__(self, levels: Mapping[str,int], earned: int, *,
                 unlocked: Iterable[str] | None=None, save_revision: int=0):
        if type(save_revision) is not int or save_revision<0:
            raise TalentError('invalid_save_revision')
        self.unlocked=frozenset(NODE_IDS if unlocked is None else unlocked)
        self.earned=earned
        self.committed=validate(levels,earned,self.unlocked)
        self.draft=dict(self.committed)
        self.save_revision=save_revision
        self.draft_revision=0

    def add(self,node: str) -> None:
        if node not in self.draft:
            raise TalentError('unknown_node')
        proposed=dict(self.draft)
        proposed[node]+=1
        validated=validate(proposed,self.earned,self.unlocked)
        self.draft=validated
        self.draft_revision+=1

    def preview_remove(self,node: str) -> RemovalPreview:
        if node not in self.draft or self.draft[node]<=0:
            raise TalentError('node_has_no_points')
        target=dict(self.draft)
        target[node]-=1
        retained=reachable_prefix(target,self.unlocked)
        validate(retained,self.earned,self.unlocked)
        refunded=tuple((n,self.draft[n]-retained[n]) for n in NODE_IDS
                       if self.draft[n]!=retained[n])
        return RemovalPreview(node,self.draft_revision,refunded)

    def confirm_remove(self,preview: RemovalPreview) -> None:
        if preview.draft_revision!=self.draft_revision:
            raise TalentError('stale_refund_preview')
        expected=self.preview_remove(preview.node_id)
        if preview!=expected:
            raise TalentError('refund_preview_mismatch')
        proposed=dict(self.draft)
        for node,count in preview.refunded:
            proposed[node]-=count
        self.draft=validate(proposed,self.earned,self.unlocked)
        self.draft_revision+=1

    def reset(self,tree: str | None=None) -> None:
        if tree is not None and tree not in TREES:
            raise TalentError('unknown_tree')
        proposed={n:(0 if tree is None or n.startswith(tree) else v)
                  for n,v in self.draft.items()}
        self.draft=validate(proposed,self.earned,self.unlocked)
        self.draft_revision+=1

    def cancel(self) -> None:
        self.draft=dict(self.committed)
        self.draft_revision+=1

    def apply(self, *, expected_save_revision: int) -> dict[str,Any]:
        if expected_save_revision!=self.save_revision:
            raise TalentError('save_revision_conflict')
        validated=validate(self.draft,self.earned,self.unlocked)
        self.committed=dict(validated)
        self.save_revision+=1
        return make_save(validated,self.earned,self.save_revision)

def make_save(levels: Mapping[str,int],earned: int,revision: int=0) -> dict[str,Any]:
    ranks=validate(levels,earned)
    return {'schema_version':SCHEMA_VERSION,'rules_version':RULES_VERSION,
            'sequence':9,'revision':revision,'earned_snapshot':earned,'nodes':ranks}

@dataclass
class MigrationProposal:
    status: str
    candidate: dict[str,Any] | None
    original_backup: Any
    reasons: list[str]

def propose_migration(payload: Mapping[str,Any],authoritative_earned: int, *,
                      unlocked: Iterable[str] | None=None) -> MigrationProposal:
    """Only explicit fixture-v1 and reference-v2 schemas are supported.

    Unknown OLD layouts propose a FULL sequence-page reset, pending confirmation.
    Unknown FUTURE schemas block downgrade. Input is never modified. Old rank sums
    and `unspent` cannot increase earned points. This does NOT parse a real client save.
    """
    check_budget(authoritative_earned)
    backup=deepcopy(payload)
    if not isinstance(payload,Mapping):
        return MigrationProposal('needs_confirmation_reset',make_save({},authoritative_earned),
                                 backup,['unsupported_payload_shape'])
    schema=payload.get('schema_version')
    if type(schema) is int and schema>SCHEMA_VERSION:
        return MigrationProposal('blocked_newer_schema',None,backup,['do_not_overwrite_newer_save'])
    try:
        if type(schema) is not int:
            raise TalentError('missing_or_invalid_schema')
        if schema==2:
            if payload.get('sequence')!=9 or payload.get('rules_version')!=RULES_VERSION:
                raise TalentError('rules_mapping_required')
            ranks=payload['nodes']
            revision=payload.get('revision',0)
            if type(revision) is not int or revision<0:
                raise TalentError('invalid_revision')
        elif schema==1 and payload.get('layout_id')=='reference_explicit_rank_v1':
            ranks=payload['ranks']
            revision=0
        else:
            raise TalentError('unknown_legacy_layout_no_guessing')
        valid=validate(ranks,authoritative_earned,unlocked)
        return MigrationProposal('compatible',make_save(valid,authoritative_earned,revision),backup,[])
    except (KeyError,TalentError) as exc:
        return MigrationProposal('needs_confirmation_reset',make_save({},authoritative_earned),
                                 backup,[str(exc)])
