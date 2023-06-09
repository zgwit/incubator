module(...,package.seeall)

--数据发送的消息队列
local msgQueue = {}

function publish(topic, payload)
    log.info("MQTT", "publish", topic)
    table.insert(msgQueue,{t=topic,p=payload,q=0})
    sys.publish("APP_SOCKET_SEND_DATA")
end


--- MQTT客户端数据发送处理
-- @param mqttClient，MQTT客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage mqttOutMsg.proc(mqttClient)
function proc(mqttClient)
    while #msgQueue>0 do
        local outMsg = table.remove(msgQueue,1)
        local result = mqttClient:publish(outMsg.t,outMsg.p,outMsg.q)
        if not result then return end
    end
    return true
end
