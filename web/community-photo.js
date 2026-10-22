// Resize locally and re-encode to JPEG before uploading (also strips EXIF).
window.suhoCommunityPhoto={pick:()=>new Promise((resolve,reject)=>{
 const input=document.createElement('input');input.type='file';input.accept='image/*';
 input.style.display='none';document.body.append(input);
 let settled=false;
 const finish=value=>{if(settled)return;settled=true;window.removeEventListener('focus',onFocus);input.remove();resolve(value);};
 const onFocus=()=>setTimeout(()=>{if(!input.files?.length)finish('');},1500);
 window.addEventListener('focus',onFocus,{once:true});
 input.oncancel=()=>finish('');
 input.onchange=async()=>{
  const file=input.files?.[0];if(!file)return finish('');
  let url;
  try{
   if(!file.type.startsWith('image/')||file.size>20*1024*1024)throw Error('사진은 20MB 이하로 선택해 주세요.');
   url=URL.createObjectURL(file);const image=new Image();image.src=url;await image.decode();
   if(!image.naturalWidth||image.naturalWidth*image.naturalHeight>60000000)throw Error('사진 크기가 너무 큽니다.');
   const scale=Math.min(1,1280/Math.max(image.naturalWidth,image.naturalHeight));
   const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(image.naturalWidth*scale));canvas.height=Math.max(1,Math.round(image.naturalHeight*scale));
   const ctx=canvas.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(image,0,0,canvas.width,canvas.height);
   let data='';for(const q of [.82,.65,.45,.25]){data=canvas.toDataURL('image/jpeg',q).split(',')[1];if(data.length<=699052)break;}
   if(data.length>699052)throw Error('사진 용량을 줄인 뒤 다시 선택해 주세요.');
   finish(JSON.stringify({mime:'image/jpeg',data}));
  }catch(e){window.removeEventListener('focus',onFocus);input.remove();reject(Error(e.message||'사진을 읽지 못했습니다.'));}
  finally{if(url)URL.revokeObjectURL(url);}
 };
 input.click();
})};
