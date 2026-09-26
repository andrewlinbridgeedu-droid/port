using System;
using System.Collections;
using System.IO;
using UnityEngine;

/// Optional live binding audit; append --audit-character-surfaces to any capture.
public sealed class CharacterSurfaceAudit20260916 : MonoBehaviour
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if(Array.IndexOf(Environment.GetCommandLineArgs(),"--audit-character-surfaces")>=0)
            new GameObject("Character surface live audit").AddComponent<CharacterSurfaceAudit20260916>();
    }
    IEnumerator Start()
    {
        var folder=Environment.GetEnvironmentVariable("MISTPORT_CHARACTER_CAPTURE");
        if(string.IsNullOrEmpty(folder)) folder=Path.Combine(Application.persistentDataPath,"surface-audit");
        folder=Path.Combine(folder,"surface-audit");Directory.CreateDirectory(folder);
        int sample=0;
        while(true)
        {
            yield return new WaitForSecondsRealtime(2);
            foreach(var component in FindObjectsByType<CharacterSurfaceRefinement20260916>(FindObjectsSortMode.None))
            {
                if(!component.gameObject.activeInHierarchy)continue;
                string actor=component.name.Replace('/','_').Replace('\\','_');
                component.SaveAudit(Path.Combine(folder,$"{sample:D3}-{actor}-{component.GetInstanceID()}.json"));
            }
            sample++;
        }
    }
}
