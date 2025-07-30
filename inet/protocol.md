## Layer 1 - 基于包的信息传输

默认端口 `10251`

`m!<src>@<dst>`, `...` - 常规消息
`m!<src>@<filter>.~`, `...` - 广播
`m!<src>@<dst>#<id>`, `...` - 常规可靠消息
`m!<src>@<dst>#!<id>` - 应答

`a`, `device-address` - 请求地址
`A`, `device-address`, `address`, `this` - 响应地址

`f`, `this` - 请求临近设备完整地址
`F`, `this` - 自身为请求的设备或自身具有请求的设备

`p` - 请求可用接入点
`P`, `address` - 自身为可用接入点

`v`, `...` - 验证
`V`, `bool`, `message` - 响应

`c`, `this` - ping请求
`C` - 回应ping

`address`: 地址
格式: `<dev>.<dev>.<dev>...`

## Layer 1.1 - 微控制器配置协议

`.` - 检查可配置的微控制器
`:`, `key`, `value` - 响应配置
`=`, `config` - 设置配置

## Layer 2 - 协议

格式:
发送目标(广播为`~`)> 传出包
发送者筛选(可选)< 传入包
E: 事件包
E为事件发出者

### 设备

新设备进入网络:
~> `p`
< `P`, `address`
记录接入点地址P

P> `a`, `dev`
< `A`, `dev`, `address`, `this`
记录`address`为自身地址A=`<parent>.<dev>`

通信
定期进行ping
ping失败后，重新请求地址

E: `f`, `dev`:
E> `F`, `address`
E: `c`:
E> `C`

E: `m!<src>@A.[left...]`, `...`:
  signal: ...
E: `m!<src>@A.[left...]#id`, `...`:
  P> `m!A.[left...]@<src>#!id`, `...`
  signal: ...
E: `m!<src>@<parent>.~`, `...`:
  signal: ...

### 路由

启动:

~> `p`
< `P`
记录地址P
P> `a`, `dev`
< `A`, `dev`, `address`, `this`
记录`address`为自身地址A，且A=`<parent>.<dev>`

E: `f`, `dev`:
E> `F`, `address`
E: `c`:
E> `C`

E: `p`:
若为P，不回应
E> `P`
E: `a`, `dev`:
E> `A`, A .. "." .. `dev`:sub(1, 3)
向设备缓存中存入`dev`:sub(1, 3)

E: `m!<src>@<dst>`, `...`:
1. `dst`为`<parent>.~`:
  ~> `m!<src>@A.~`, `...`
2. `<dst>`以A开头: `A.<next>.<left...>`
  设备缓存已知`<next>`:
    `<next>`> `m!<src>@<dst>`, `...`
  其他:
    ~>`f`, `<next>`
    <`F`, `address`
    向设备缓存中存入`address`
    `address`> `m!<src>@<dst>`, `...`
3. 其他:
  P> `m!<src>@<dst>`, `...`

### 交换

启动:
~> `p`
< `P`, `address`
记录地址P, 记`address`为`<parent>`

E: `c`:
E> `C`

E: `p`:
若为P，不回应
E> `P`
E: `a`, `dev`:
P> `a`, `dev`
P< `A`, `dev`, `address`
E> `A`, `dev`, `address`
向设备存储中存入`dev`

E: `f`, `dev`, 来自P:
E> `F`, 自身地址

E: `m!<src>@<dst>`, `...`:
1. `dst`为`<parent>.~`:
  ~> `m!<src>@<parent>.~`, `...`
2. `dst`以`<parent>`开头: `<parent>.<next>.<left...>`
  设备缓存已知`<next>`:
    `<next>`> `m!<src>@<dst>`, `...`
  其他:
    ~>`f`, `<next>`
    <`F`, `address`
    向设备缓存中存入`address`
    `address`> `m!<src>@<dst>`, `...`
3. 其他:
  P> `m!<src>@<dst>`, `...`
