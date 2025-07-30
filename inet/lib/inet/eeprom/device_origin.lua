do
local c,M=computer,component.proxy(component.list("modem")())
local A,T,lp,r,tmp,bc,P=M.address,c.uptime,0,{},nil,"",10251
local function wn(t)while t>T()do if not IH(c.pullSignal(t-T()))then return end end return true end
IC,IM={},{}
local S,B=function(s,ms,...)M.send(s,P,ms,...)end,function(...)M.broadcast(P,...)end
function IE()M.open(P) B("p") local t=T()+5 IC.p=nil while IC.a==nil and T()<t do wn(t) end lp=T()+5 end
function IA()return T()>lp+10 end
function IS(d,...)S(IC.p,"m!"..IC.a.."@"..d,...)end
function IH(t,a,s,p,d,m,...)
if lp<T()and IC.p then S(IC.p,"c",IC.t) end
for k,v in pairs(r)do if v<T()then r[k]=nil end end
if t~="modem_message"or a~=A or p~=P then return t,a,s,p,d,m,... end
if m=="P"and({...})[3]==nil and IC.p==nil then IC.p=s S(s,"v")end
if m=="V"and({...})[1]then S(s,"a",A) end
if m=="A"then _,IC.a,IC.t=... bc=IC.a:gsub("[^%.]+$","").."~"end
if m=="C"then lp=T()+5 end
if m=="f"and ({...})[1]==IC.t then S(s,"F",IC.t)end
if m:sub(1,1)=="m"then local sr,ds,i=m:match("^m!(.+)@([^#]+)#?(.*)$") if ds:sub(1,#IC.a)==IC.a then if i~=""then
S(s,"m!"..IC.a.."@"..sr.."#!"..i) tmp=r[i] r[i]=T()+5 if tmp~=nil then return end end table.insert(IM,{sr,ds,...})
elseif ds:sub(1,#bc)==bc then table.insert(IM,{sr,ds,...}) end end
end
end

IE()
IS("someplace.computer", "Hello")
while true do IH(computer.pullSignal(0.1)) if IM[1] then computer.beep(table.unpack(table.remove(IM,1),3)) end end