A=component
B=computer
C=function(a)return A.proxy(A.list(a)())end
D=C("modem")
Da=D.address
E=C("eeprom")
F=computer.pushSignal
Cf={connect="",connect_verify="",hidden=false,password="",name="Switch-"..Da:sub(1,8),wireless_strength=400}
Co=Cf.connect
Na=Cf.name
Pw=Cf.password
Pa=nil
Ad=nil
Es=-1
H=computer.beep
De={}
Ac={}
SC={}
D.open(10251)
S=function(s,...)D.send(s,10251,...)end
R=function(...)D.broadcast(10251,...)end
N=function(s)return s:sub(1,3)end
T=B.uptime
Lt=T()
Pt=T()
LT=T()
I=function(k,v,...)return k and "| "..k.."="..tostring(v)..I(...) or ""end
Ev={modem_message=function(s,p,d,m,...)if p==10251 and d<5 then if m=="."then S(s,":","",I("Pa",N(Pa or "nil"),"Es",Es,"Fm",B.freeMemory()))
for k,v in pairs(Cf)do S(s,":",k,v)end return elseif m=="="then H(1000)Cf=...E.set(E.get():gsub("\nCf=[^\n]*","\nCf="..Cf))computer.shutdown(true)end elseif(".=:,"):match("%"..m)then return end F("inet",nil,s,m,...)end,
inet=function(s,m,...) if m:sub(1,1)=="m" then return Ms.m(s,m,...) elseif Ms[m] then return Ms[m](s,...) end end}
Ms={
-- client
P=function(s,a,...) if s:sub(1,#Co)==Co and Es<0 then Pa=s; Ac[s]=true; S(Pa,"v",Cf.connect_verify) Ad=a end end,
V=function(s,r,m) if not r then Ad="Verify failed "..m Es=-1 end Es=1 end,
C=function() Pt=T()+5 end,
-- access point
p=function(s) if Es==1 and s~=Pa and not Cf.hidden then S(s,"P",Ad or"l",Na,Pw~=""and"password"or nil) end end,
c=function(s) if Es==1 then S(s,"C") De[N(s)]=s end end,
v=function(s,p) if p==Pw or Pw=="" then Ac[s]=true S(s,"V",true) else S(s,"V",false,p==""and"Password is required"or"Password is incorrect") end end,
-- switch
a=function(s,d) if not Ac[s] then S(s,"!") else De[N(d)]=s SC[d]=s S(Pa,"a",d) end end,
A=function(s,d,a) S(SC[d],"A",d,a) SC[d]=nil end,
f=function(s,d) if N(Da)==d and s==Pa then S(s,"F",d) else R("f",d) SC[d]=s end end,
F=function(s,d) De[d]=s S(SC[d],"F",d) SC[d]=nil end,
m=function(s,m,...) if not Ac[s] then S(s,"!") else Sr,Ds,Id=m:match("^m!(.+)@([^#]+)#?(.*)$")
if Ds:sub(1,#Ad)==Ad then Ne=Ds:match("^"..Ad:gsub("%.","%%.")..(Ad~=""and"%."or"").."([^%.]*)")
if Ds:find(N(s)) and s ~= Pa then return end
if Ne=="~" then if s ~= Pa then return S(Pa,m,...) end for _,s in pairs(De) do if s ~= Pa then S(s,m,...) end end return end
if De[Ne] then return S(De[Ne],m,...) else return S(Pa,m,...) end
else S(Pa,m,...) end
end end
}
R("p")
if D.isWireless() then D.setStrength(Cf.wireless_strength) end
while true do P=table.pack(computer.pullSignal(.5))if P[1]and Ev[P[1]]then St,Er=xpcall(Ev[P[1]],debug.traceback,table.unpack(P,3)) if not St then R(",",table.unpack(P,3),Er) end end
if LT+.45<T() then
if T()>Lt+5 and Es==-1 then R("p") Lt=T() end
if Es==1 and T()>Pt then S(Pa,"c")if T()>Pt+10 then Es=-1 Pa=nil De={} end end
LT=T()
end
end