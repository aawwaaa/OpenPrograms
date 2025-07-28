A=component
B=computer
C=function(a)return A.proxy(A.list(a)())end
D=C("modem")
E=C("eeprom")
F=computer.pushSignal
Cf={}
H=computer.beep
S=function(s,...)D.send(s,10251,...)end
T=function(...)D.broadcast(10251,...)end
I=function(k,v,...)return k and "| "..k.."="..tostring(v)..I(...) or ""end
D.open(10251)
Ev={modem_message=function(s,p,d,m,...)if p==10251 and d<5 then if m=="."then S(s,":","",I())for k,v in pairs(Cf)do S(s,":",k,v)end return elseif m=="="then H(1000)Cf=...E.set(E.get():gsub("\nCf=[^\n]*","\nCf="..Cf))computer.shutdown(true)end elseif(".=:"):match("%"..m)then return end F("inet",nil,s,m,...)end,inet=function(s,m,...)end}
while true do P=table.pack(computer.pullSignal(.1))if P[1]and Ev[P[1]]then Ev[P[1]](table.unpack(P,3))end end