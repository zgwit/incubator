module(...,package.seeall)

require"misc"
require"mqtt"
require"mqttOutMsg"
require"mqttInMsg"

local ready = false

--- MQTT连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage mqttTask.isReady()
function isReady()
    return ready
end

log.info("MQTT", "module")

--启动MQTT客户端任务

sys.taskInit(function()
    log.info("MQTT", "mqtt task")

    local retryConnectCnt = 0
    while true do
        log.info("MQTT", "mqtt task loop")

        if not socket.isReady() then
            log.info("MQTT", "mqtt network not ready")

            retryConnectCnt = 0
            --等待网络环境准备就绪，超时时间是5分钟
            sys.waitUntil("IP_READY_IND",300000)
            --sys.waitUntil("IP_READY_IND",30000)
        end
        
        log.info("mqtt network ready")
        if socket.isReady() then
            local imei = misc.getImei()
            log.info("MQTT", "imei", imei)

            --创建一个MQTT客户端
            local mqttClient = mqtt.client(imei, 60)
            --阻塞执行MQTT CONNECT动作，直至成功
            if mqttClient:connect("git.zgwit.com",1883,"tcp") then
                log.info("MQTT", "mqtt connect success")
                retryConnectCnt = 0
                ready = true
                --订阅主题
                --if mqttClient:subscribe({["/event0"]=0, ["/中文event1"]=1}) then
                --    mqttOutMsg.init()
                    --循环处理接收和发送的数据
                    while true do
                        if not mqttInMsg.proc(mqttClient) then log.error("mqttTask.mqttInMsg.proc error") break end
                        if not mqttOutMsg.proc(mqttClient) then log.error("mqttTask.mqttOutMsg proc error") break end
                    end
                --    mqttOutMsg.unInit()
                --end
                ready = false
            else
                log.info("MQTT", "mqtt connect failed")
                retryConnectCnt = retryConnectCnt+1
            end
            --断开MQTT连接
            mqttClient:disconnect()
            if retryConnectCnt>=5 then link.shut() retryConnectCnt=0 end
            sys.wait(5000)
        else
            --进入飞行模式，20秒之后，退出飞行模式
            net.switchFly(true)
            sys.wait(20000)
            net.switchFly(false)
        end
    end
end)
