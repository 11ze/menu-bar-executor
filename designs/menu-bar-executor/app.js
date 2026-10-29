'use strict';
const seedCommands = [
  {id:1,name:'当前 IP 地址',command:'ipconfig getifaddr en0',group:'状态速览',auto:true,direct:true,notify:false,output:'192.168.31.108'},
  {id:2,name:'查看 Git 分支',command:'git branch --show-current',group:'状态速览',auto:true,direct:false,notify:false,directory:'~/Developer/menu-bar-executor',output:'main'},
  {id:3,name:'启动 Docker 服务',command:'open -a Docker',group:'开发工具',auto:false,direct:true,notify:true,output:''},
  {id:4,name:'启动本地开发环境',command:'docker compose up -d',group:'开发工具',auto:false,direct:false,notify:true,directory:'~/Developer/workspace',output:'Container workspace-db  Started\nContainer workspace-app  Started'},
  {id:5,name:'清理 Xcode 缓存',command:'rm -rf ~/Library/Developer/Xcode/DerivedData/*',group:'开发工具',auto:false,direct:true,notify:true,output:''},
  {id:6,name:'显示隐藏文件',command:'defaults write com.apple.finder AppleShowAllFiles -bool true\nkillall Finder',group:'日常操作',auto:false,direct:true,notify:true,output:''},
  {id:7,name:'刷新 DNS 缓存',command:'sudo dscacheutil -flushcache',group:'日常操作',auto:false,direct:true,notify:true,output:'sudo: a terminal is required to read the password',failed:true},
  {id:8,name:'打开下载文件夹',command:'open ~/Downloads',group:'日常操作',auto:false,direct:true,notify:false,output:''}
];
let commands=structuredClone(seedCommands);
let records=[
 {id:101,name:'启动本地开发环境',command:'docker compose up -d',success:true,time:'今天 10:42:08',output:'Container workspace-db  Started\nContainer workspace-app  Started'},
 {id:102,name:'刷新 DNS 缓存',command:'sudo dscacheutil -flushcache',success:false,time:'今天 10:38:51',output:'sudo: a terminal is required to read the password'},
 {id:103,name:'启动 Docker 服务',command:'open -a Docker',success:true,time:'今天 10:37:22',output:''},
 {id:104,name:'显示隐藏文件',command:'defaults write com.apple.finder AppleShowAllFiles -bool true\nkillall Finder',success:true,time:'昨天 18:06:34',output:''}
];
const notes={
 palette:['01','COMMAND PALETTE','从想到执行，只隔一个回车。','名称优先，结果就近。自动执行的输出留在行内，完整内容按需展开；键盘与鼠标沿用同一套选择规则。'],
 commands:['02','COMMAND LIBRARY','常用命令，各有位置。','分组建立阅读节奏，命令原文提供识别线索。搜索、添加和操作入口固定，列表滚动时仍能随时管理。'],
 editor:['03','COMMAND EDITOR','把执行行为，说明白。','名称与命令分开编辑，目录与分组按需填写。自动执行、直接执行与通知各自说明影响，保存前保留完整草稿。'],
 general:['04','PREFERENCES','只留下需要决定的设置。','呼出与输入、启动与更新、配置文件，按使用目的归类。沿用现有设置项，配置导入前说明覆盖范围。'],
 history:['05','EXECUTION HISTORY','执行之后，有迹可查。','左侧定位记录，右侧阅读输出。只呈现当前实际保存的信息：执行内容、时间、成功或失败，以及最多 500 字符输出。']
};
let page='palette',query='',historyQuery='',selected=0,selectedRecord=101,onlyFailed=false,autoState='success',closed=false;
let editorId=null,editorOrigin=null,returnFocus=null,popoverFocus=null;
const settings={launch:true,updates:true,input:'不切换',shortcut:'⌃ ⌥ Space'};
const $=s=>document.querySelector(s);
const escapeHTML=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const traffic='<div class="traffic" aria-hidden="true"><i></i><i></i><i></i></div>';
const groups=()=>[...new Set(commands.map(c=>c.group||'未分组'))];
function filtered(){return groups().flatMap(group=>commands.filter(c=>(c.group||'未分组')===group&&c.name.toLocaleLowerCase().includes(query.toLocaleLowerCase())))}
function toast(message){$('#toast').textContent=message;$('#toast').classList.add('visible');clearTimeout(toast.timer);toast.timer=setTimeout(()=>$('#toast').classList.remove('visible'),2600)}
function searchbox(value,id){return `<div class="searchbox"><span class="search-symbol" aria-hidden="true"></span><input id="${id}" placeholder="搜索命令名称" aria-label="搜索命令名称" value="${escapeHTML(value)}">${value?'<button class="clear" data-action="clearSearch" aria-label="清空搜索">×</button>':''}</div>`}
function windowbar(title,tabs=false){return `<header class="windowbar">${traffic}<span class="windowtitle">${title}</span>${tabs?`<div class="windowtabs" aria-label="设置标签"><button data-page="commands" class="${page==='commands'?'active':''}">命令</button><button data-page="general" class="${page==='general'?'active':''}">通用</button></div>`:''}</header>`}
function empty(title,detail,action,label){return `<div class="empty"><div class="empty-icon" aria-hidden="true">›_</div><strong>${title}</strong><p>${detail}</p><button data-action="${action}">${label}</button></div>`}
function palette(){
 if(closed)return `<div class="closed">${empty('命令面板已关闭','正式版本可用全局快捷键再次呼出。','reopen','重新打开面板')}</div>`;
 const list=filtered();selected=Math.max(0,Math.min(selected,list.length-1));
 let previousGroup=null;
 const rows=list.map((c,index)=>{const group=c.group||'未分组';let heading=previousGroup!==group?`<div class="group-label">${escapeHTML(group)}</div>`:'';previousGroup=group;
 const output=autoState==='loading'?'正在执行…':autoState==='failed'?'执行失败':autoState==='empty'?'无输出':(c.output||'无输出');
 const canView=c.auto&&autoState!=='loading'&&autoState!=='empty'&&(autoState==='failed'||!!c.output);
 return heading+`<div class="palette-row ${selected===index?'selected':''}" data-index="${index}"><button class="execute" data-execute="${c.id}" title="${escapeHTML(c.name)}">${escapeHTML(c.name)}</button>${c.auto?`<${canView?'button':'div'} class="result" ${canView?`data-result="${c.id}" aria-label="查看${escapeHTML(c.name)}的结果"`:''}><i class="dot ${autoState==='failed'?'failed':autoState==='loading'?'loading':''}"></i><span>${escapeHTML(output)}</span></${canView?'button':'div'}>`:''}${index<9?`<kbd>⌘${index+1}</kbd>`:''}</div>`}).join('');
 return `<div class="window palette" data-screen-label="命令面板"><div class="palette-search"><span class="search-symbol" aria-hidden="true"></span><input id="palette-search" aria-label="搜索命令名称" placeholder="搜索命令…" autocomplete="off" value="${escapeHTML(query)}">${query?'<button class="clear" data-action="clearSearch" aria-label="清空搜索">×</button>':'<kbd>esc</kbd>'}</div><div class="palette-list">${rows||empty(commands.length?'没有匹配的命令':'还没有命令',commands.length?'试试其他名称，或清空搜索。':'添加一条常用命令，随时呼出执行。',commands.length?'clearSearch':'add',commands.length?'清空搜索':'添加命令')}</div><footer class="windowfoot"><div class="palette-help"><kbd>↑</kbd><kbd>↓</kbd><span>选择</span><kbd>↵</kbd><span>执行</span></div><div class="row"><button data-page="history">执行历史</button><button data-page="commands">设置 <span class="muted">⌘,</span></button></div></footer></div><label class="preview-state">预览自动执行状态<select id="auto-state"><option value="success">成功 · 有输出</option><option value="loading">执行中</option><option value="failed">失败</option><option value="empty">成功 · 无输出</option></select></label>`;
}
function commandLibrary(){const list=filtered();return `<section class="window" data-screen-label="命令管理">${windowbar('设置',true)}<div class="toolbar">${searchbox(query,'command-search')}<button class="primary" data-action="add">＋ 添加命令</button></div><div class="countbar"><span>${list.length} 条命令</span><span>按分组显示</span></div><div class="commands-scroll">${list.length?groups().map(group=>{const items=list.filter(c=>(c.group||'未分组')===group);return items.length?`<h2 class="manage-group">${escapeHTML(group)}</h2>`+items.map(c=>`<div class="command-row"><div class="grow"><h3>${escapeHTML(c.name)} ${c.auto?'<span class="tag">自动执行</span>':''}</h3><p>${escapeHTML(c.command)}</p></div><div class="row"><button data-edit="${c.id}">编辑</button><button data-move="${c.id}" aria-label="在组内上移${escapeHTML(c.name)}" ${query||commands.filter(x=>(x.group||'未分组')===group)[0].id===c.id?'disabled':''}>↑</button></div></div>`).join(''):''}).join(''):empty(commands.length?'没有匹配的命令':'还没有命令','名称用于搜索，分组方便查找。',commands.length?'clearSearch':'add',commands.length?'清空搜索':'添加命令')}</div><footer class="windowfoot"><span>在组内调整顺序，与命令面板同步</span><span>${commands.filter(c=>c.auto).length} 条自动执行</span></footer></section>`}
function toggle(key,label){return `<button class="switch" role="switch" aria-label="${label}" aria-checked="${settings[key]}" data-toggle="${key}"></button>`}
function general(){return `<section class="window" data-screen-label="通用设置">${windowbar('设置',true)}<div class="settings-body"><section class="settings-section"><h3>呼出与输入</h3><div class="settings-box"><div class="setting"><div><span>全局快捷键</span><p>在任何应用中打开或关闭命令面板。</p></div><div class="row"><button data-action="shortcut" class="mono">${escapeHTML(settings.shortcut||'录制快捷键…')}</button><button class="quiet" data-action="clearShortcut">清除</button></div></div><div class="setting"><div><span>面板输入法</span><p>打开时切换，关闭后恢复原输入法。</p></div><select id="input-source" aria-label="面板输入法"><option>不切换</option><option>ABC</option><option>简体拼音</option></select></div></div></section><section class="settings-section"><h3>启动、通知与更新</h3><div class="settings-box"><div class="setting"><span>登录时启动</span>${toggle('launch','登录时启动')}</div><div class="setting"><div><span>系统通知</span><p>每条命令可单独设置完成通知。</p></div><button data-action="notification">查看说明 ↗</button></div><div class="setting"><div><span>自动检查更新</span><p>启动时检查新版本，有更新时提醒。</p></div>${toggle('updates','自动检查更新')}</div></div></section><section class="settings-section"><h3>配置文件</h3><div class="settings-box"><div class="setting"><div><span>备份与恢复</span><p>导入会替换命令、分组和通用设置。</p></div><div class="row"><button data-action="export">导出</button><button data-action="import">导入…</button></div></div><div class="path">~/.config/menu-bar-executor/settings.json</div></div></section></div><footer class="windowfoot"><span>MenuBarExecutor</span><span>命令执行超时：30 秒</span></footer></section>`}
function history(){const list=records.filter(r=>(!onlyFailed||!r.success)&&r.name.toLocaleLowerCase().includes(historyQuery.toLocaleLowerCase()));const record=list.find(r=>r.id===selectedRecord)||list[0];return `<section class="window" data-screen-label="执行历史">${windowbar('执行历史')}<div class="toolbar">${searchbox(historyQuery,'history-search')}<label class="row small"><input type="checkbox" id="only-failed" ${onlyFailed?'checked':''}>仅失败</label><button data-action="clearHistory" ${records.length?'':'disabled'}>清空历史</button></div>${record?`<div class="history-body"><div class="history-list">${list.map(r=>`<button class="history-item ${r.id===record.id?'active':''}" data-record="${r.id}"><strong><i class="dot ${r.success?'':'failed'}"></i>${escapeHTML(r.name)}</strong><time>${escapeHTML(r.time)}</time></button>`).join('')}</div><article class="history-detail"><h2>${escapeHTML(record.name)}</h2><div class="meta"><span class="${record.success?'success':'danger'}">${record.success?'执行成功':'执行失败'}</span><time>${escapeHTML(record.time)}</time></div><h3 class="detail-label">执行内容</h3><code>${escapeHTML(record.command)}</code><div class="row spread detail-label"><h3 style="font-size:10px;font-weight:500">输出结果</h3><button class="quiet" data-copy-record="${record.id}" ${record.output?'':'disabled'}>复制输出</button></div><pre class="output">${escapeHTML(record.output||'（无输出）')}</pre><p class="small">每条记录最多保存 500 字符输出。</p></article></div>`:`<div style="min-height:410px">${empty(records.length?'没有匹配的记录':'暂无执行记录',records.length?'尝试其他名称，或清除筛选。':'手动执行命令后，记录会显示在这里。',records.length?'resetHistory':'reopen',records.length?'清除筛选':'打开命令面板')}</div>`}<footer class="windowfoot"><span>${list.length} 条记录</span><span>最近 100 条 · 不含自动执行</span></footer></section>`}
function editorMarkup(c,inline=false){return `<form class="sheet ${inline?'inline':''}" id="editor-form" aria-label="${c.id?'编辑命令':'添加命令'}"><header class="sheet-head"><h2>${c.id?'编辑命令':'添加命令'}</h2><p>名称用于搜索，命令内容交给 zsh 执行。</p></header><div class="form-body"><label class="field">命令名称<input name="name" value="${escapeHTML(c.name)}" placeholder="例如：启动 Docker 服务" required></label><label class="field">命令内容<textarea name="command" spellcheck="false" required>${escapeHTML(c.command)}</textarea></label><div class="field-pair"><label class="field">分组 <span class="muted">可选</span><input name="group" list="group-options" placeholder="选择或输入分组" value="${escapeHTML(c.group)}"><datalist id="group-options">${groups().map(g=>`<option value="${escapeHTML(g)}"></option>`).join('')}</datalist></label><label class="field">工作目录 <span class="muted">可选</span><div class="row"><input class="grow" name="directory" placeholder="默认工作目录" value="${escapeHTML(c.directory)}"><button type="button" data-action="directory">选择…</button></div><span class="small">支持 ~，留空使用默认目录。</span></label></div><div class="form-divider"></div><label class="option"><input name="auto" type="checkbox" ${c.auto?'checked':''}><span>打开面板时自动执行<small>每次打开都会运行；结果显示在行内，不计入历史、不通知。</small></span></label><label class="option"><input name="direct" type="checkbox" ${c.direct?'checked':''}><span>直接执行<small>跳过 ~/.zshrc；其中的 alias、函数和环境变量不可用。</small></span></label><label class="option"><input name="notify" type="checkbox" ${c.notify?'checked':''}><span>手动执行完成后通知</span></label><p class="small">命令超过 30 秒会终止。</p></div><footer class="form-foot"><button type="button" data-action="cancelEditor">取消</button>${c.id?'<button type="button" class="quiet danger" data-action="delete">删除命令…</button>':''}<button type="submit" class="primary">保存命令</button></footer></form>`}
function render(focusId){const selection=focusId?$("#"+focusId)?.selectionStart:null;const note=notes[page];$('#screen-number').textContent=note[0]+' / 05';$('#screen-kind').textContent=note[1];$('#note-title').textContent=note[2];$('#note-text').textContent=note[3];document.querySelectorAll('nav button').forEach(b=>{b.classList.toggle('active',b.dataset.page===page);b.setAttribute('aria-current',b.dataset.page===page?'page':'false')});if(page==='editor'){const c=commands.find(c=>c.id===editorId)||commands[2]||{name:'',command:'',notify:true};editorId=c.id??null;$('#stage').innerHTML=`<div class="window editor-window" data-screen-label="命令编辑">${editorMarkup(c,true)}</div>`;validateEditor()}else $('#stage').innerHTML=page==='palette'?palette():page==='commands'?commandLibrary():page==='general'?general():history();if($('#auto-state'))$('#auto-state').value=autoState;if($('#input-source'))$('#input-source').value=settings.input;if(focusId&&$('#'+focusId)){$('#'+focusId).focus();if(selection!==null)$('#'+focusId).setSelectionRange(selection,selection)}}
function navigate(next){closePopover();$('#modal-layer').innerHTML='';editorOrigin=null;page=Object.hasOwn(notes,next)?next:'palette';query='';selected=0;closed=false;location.hash=page;render();if(page==='palette')$('#palette-search')?.focus()}
function openEditor(id){returnFocus=document.activeElement;editorOrigin=page;editorId=id??null;const c=commands.find(c=>c.id===id)||{name:'',command:'',notify:true};$('#modal-layer').innerHTML=`<div class="backdrop"><section role="dialog" aria-modal="true" aria-label="${id?'编辑命令':'添加命令'}">${editorMarkup(c)}</section></div>`;validateEditor();$('#editor-form input').focus()}
function closeEditor(){if(editorOrigin){$('#modal-layer').innerHTML='';editorOrigin=null;returnFocus?.focus()}else navigate('commands')}
function validateEditor(){const f=$('#editor-form');if(f)f.querySelector('[type="submit"]').disabled=!f.elements.name.value.trim()||!f.elements.command.value.trim()}
function confirmDialog(title,text,action,label){const holder=document.createElement('div');holder.id='confirmation';holder.className='backdrop';holder.style.zIndex=25;holder.innerHTML=`<section class="sheet confirmation" role="dialog" aria-modal="true" aria-label="${title}"><header class="sheet-head"><h2>${title}</h2></header><div class="form-body"><p>${escapeHTML(text)}</p></div><footer class="form-foot"><button data-action="cancelConfirm">取消</button><button class="primary" data-action="${action}">${label}</button></footer></section>`;document.body.append(holder);holder.querySelector('button').focus()}
function closeConfirmation(){$('#confirmation')?.remove();$('#editor-form [data-action="delete"]')?.focus()}
function execute(id){const c=commands.find(c=>c.id===id);if(!c)return;records.unshift({id:Date.now(),name:c.name,command:c.command,success:!c.failed,time:'今天 '+new Date().toLocaleTimeString('zh-CN',{hour12:false}),output:(c.output||'').slice(0,500)});records=records.slice(0,100);toast(`已模拟执行「${c.name}」`)}
function closePopover(){if(!$('#popover-layer').firstChild)return;$('#popover-layer').innerHTML='';popoverFocus?.focus();popoverFocus=null}
function showResult(id,anchor){closePopover();const c=commands.find(c=>c.id===id);popoverFocus=anchor;const result=autoState==='failed'?'执行失败':(c.output||'无输出');$('#popover-layer').innerHTML=`<section class="popover" role="dialog" aria-label="执行结果"><div class="row spread"><h3>${escapeHTML(c.name)}</h3><button class="quiet" data-action="closeResult" aria-label="关闭结果">×</button></div><pre>${escapeHTML(result)}</pre><button data-action="copyResult">复制结果</button></section>`;const rect=anchor.getBoundingClientRect(),p=$('.popover');p.style.left=Math.max(12,Math.min(rect.left,innerWidth-p.offsetWidth-12))+'px';p.style.top=Math.max(12,Math.min(rect.bottom+8,innerHeight-p.offsetHeight-12))+'px';p.querySelector('button').focus()}
async function copy(value){try{await navigator.clipboard.writeText(value);toast('已复制')}catch{toast('浏览器未允许复制，请选择文字复制')}}
let composingInput=null;
function updateInput(t){
 if(t.id==='palette-search'||t.id==='command-search'){query=t.value;selected=0;render(t.id)}
 else if(t.id==='history-search'){historyQuery=t.value;render(t.id)}
 else if(t.closest('#editor-form'))validateEditor();
}
document.addEventListener('compositionstart',e=>{composingInput=e.target});
document.addEventListener('compositionend',e=>{composingInput=null;updateInput(e.target)});
document.addEventListener('input',e=>{if(!e.isComposing&&e.target!==composingInput)updateInput(e.target)});
document.addEventListener('change',e=>{if(e.target.id==='auto-state'){autoState=e.target.value;render()}if(e.target.id==='only-failed'){onlyFailed=e.target.checked;render()}if(e.target.id==='input-source')settings.input=e.target.value});
document.addEventListener('submit',e=>{if(e.target.id!=='editor-form')return;e.preventDefault();const f=e.target;const old=commands.find(c=>c.id===editorId);const command={...old,id:editorId??Date.now(),name:f.elements.name.value.trim(),command:f.elements.command.value,group:f.elements.group.value||'',directory:f.elements.directory.value,auto:f.elements.auto.checked,direct:f.elements.direct.checked,notify:f.elements.notify.checked};if(!command.name||!command.command.trim())return;if(old)commands[commands.indexOf(old)]=command;else commands.push(command);if(editorOrigin){$('#modal-layer').innerHTML='';editorOrigin=null;render()}else navigate('commands');toast('命令已保存到示例数据')});
document.addEventListener('click',e=>{
 if($('#popover-layer').firstChild&&!e.target.closest('.popover')&&!e.target.closest('[data-result]'))closePopover();
 const b=e.target.closest('button');if(!b){if(!e.target.closest('.popover'))closePopover();return}
 if(b.id==='theme'){const dark=document.documentElement.dataset.theme!=='dark';document.documentElement.dataset.theme=dark?'dark':'light';b.innerHTML=dark?'◐ <span>浅色</span>':'◐ <span>深色</span>';return}
 if(b.dataset.page){navigate(b.dataset.page);return}if(b.dataset.edit){openEditor(Number(b.dataset.edit));return}if(b.dataset.execute){execute(Number(b.dataset.execute));return}if(b.dataset.result){showResult(Number(b.dataset.result),b);return}
 if(b.dataset.move){const c=commands.find(c=>c.id===Number(b.dataset.move)),same=commands.filter(x=>(x.group||'未分组')===(c.group||'未分组')),previous=same[same.indexOf(c)-1];if(previous){const i=commands.indexOf(c),j=commands.indexOf(previous);[commands[i],commands[j]]=[commands[j],commands[i]];render()}return}
 if(b.dataset.record){selectedRecord=Number(b.dataset.record);render();return}if(b.dataset.copyRecord){copy(records.find(r=>r.id===Number(b.dataset.copyRecord)).output);return}if(b.dataset.toggle){settings[b.dataset.toggle]=!settings[b.dataset.toggle];b.setAttribute('aria-checked',settings[b.dataset.toggle]);return}
 const action=b.dataset.action;
 if(action==='add')openEditor();
 if(action==='cancelEditor')closeEditor();
 if(action==='clearSearch'){if(page==='history')historyQuery='';else query='';selected=0;render(page==='palette'?'palette-search':page==='commands'?'command-search':'history-search')}
 if(action==='reopen')navigate('palette');
 if(action==='resetHistory'){historyQuery='';onlyFailed=false;render()}
 if(action==='delete')confirmDialog('删除命令？','将删除此命令。取消后保留编辑草稿。','confirmDelete','删除命令');
 if(action==='confirmDelete'){commands=commands.filter(c=>c.id!==editorId);closeConfirmation();if(editorOrigin){$('#modal-layer').innerHTML='';editorOrigin=null;render()}else navigate('commands');toast('已删除示例命令')}
 if(action==='cancelConfirm')closeConfirmation();
 if(action==='clearHistory')confirmDialog('清空执行历史？','清空示例中的全部执行记录，刷新页面可恢复。','confirmClear','清空历史');
 if(action==='confirmClear'){records=[];closeConfirmation();render()}
 if(action==='closeResult')closePopover();
 if(action==='copyResult')copy($('.popover pre').textContent);
 if(action==='directory')toast('目录选择示意：正式版本打开 macOS 目录选择器；原型可直接填写路径');
 if(action==='notification')toast('正式版本打开系统通知设置；原型不读取系统权限');
 if(action==='shortcut')toast('快捷键录制示意：正式版本使用原生录制控件');
 if(action==='clearShortcut'){settings.shortcut='';render()}
 if(action==='export')toast('导出示意：正式版本选择位置保存 JSON 配置');
 if(action==='import')confirmDialog('导入配置','正式版本先选择 JSON 文件，再确认替换命令、分组和通用设置。原型不读取或覆盖真实配置。','closeImport','知道了');
 if(action==='closeImport')closeConfirmation();
});
let lastPointer;
document.addEventListener('pointermove',e=>{if(lastPointer?.x===e.clientX&&lastPointer?.y===e.clientY)return;lastPointer={x:e.clientX,y:e.clientY};if(page!=='palette'||$('#modal-layer').firstChild||$('#popover-layer').firstChild)return;const row=e.target.closest('.palette-row');if(!row)return;selected=Number(row.dataset.index);document.querySelectorAll('.palette-row').forEach(r=>r.classList.toggle('selected',Number(r.dataset.index)===selected))});
document.addEventListener('keydown',e=>{
 if(e.isComposing||e.keyCode===229)return;
 if(e.key==='Escape'){e.preventDefault();if($('#confirmation'))closeConfirmation();else if($('#popover-layer').firstChild)closePopover();else if($('#modal-layer').firstChild)closeEditor();else if(page==='palette'){if(query){query='';render('palette-search')}else{closed=true;render()}}else if(page==='editor')closeEditor();return}
 const scope=$('#confirmation')||$('#modal-layer .sheet')||$('.popover');
 if(scope){if(e.key==='Tab'){const focusable=[...scope.querySelectorAll('button:not(:disabled),input,textarea,select')];const first=focusable[0],last=focusable.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}}return}
 if(page!=='palette'||closed)return;
 if(e.metaKey&&e.key===','){e.preventDefault();navigate('commands');return}
 const list=filtered();if(e.metaKey&&/^[1-9]$/.test(e.key)){e.preventDefault();if(list[Number(e.key)-1])execute(list[Number(e.key)-1].id);return}
 if(document.activeElement?.tagName==='BUTTON'||document.activeElement?.tagName==='SELECT')return;
 if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();selected=Math.max(0,Math.min(list.length-1,selected+(e.key==='ArrowDown'?1:-1)));document.querySelectorAll('.palette-row').forEach(r=>r.classList.toggle('selected',Number(r.dataset.index)===selected));$('.palette-row.selected')?.scrollIntoView({block:'nearest'})}
 if(e.key==='Enter'&&list[selected]){e.preventDefault();execute(list[selected].id)}
});
window.addEventListener('hashchange',()=>{const next=location.hash.slice(1);if(next!==page)navigate(next)});
navigate(location.hash.slice(1)||'palette');
