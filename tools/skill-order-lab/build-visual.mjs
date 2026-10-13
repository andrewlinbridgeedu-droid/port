import {readFileSync,writeFileSync} from 'node:fs';
const destination=process.argv[2];
if(!destination)throw new Error('Provide an absolute output .html path');
if(!destination.startsWith('/'))throw new Error('Use an absolute path');
const model=readFileSync(new URL('./model.mjs',import.meta.url),'utf8').replace(/^export /gm,'');
const template=readFileSync(new URL('./visual-template.html',import.meta.url),'utf8');
writeFileSync(destination,template.replace('__MODEL__',model));
console.log(destination);
