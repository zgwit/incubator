module(...,package.seeall)

require"utils"
require"common"

--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("testUart")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("modbusrtu")后，在不需要串口时调用pm.sleep("testUart")
pm.wake("modbusrtu")

local uart_id = 1
local uart_baud = 9600

local imei = misc.getImei()
log.info("imei", imei)

local values = {}

local function modbus_send(slaveaddr,Instructions,reg,value)
    local data = (string.format("%02x",slaveaddr)..string.format("%02x",Instructions)..string.format("%04x",reg)..string.format("%04x",value)):fromHex()
    local modbus_crc_data= pack.pack('<h', crypto.crc16("MODBUS",data))
    local data_tx = data..modbus_crc_data
	--uart.on(uart_id,"receive")
	--uart.set_rs485_oe(uart_id, pio.P0_23, 1)
    uart.write(uart_id,data_tx)
	log.info("modbus send", string.toHex(data_tx))
end

local function modbus_read()
    --local values = {}
    local cacheData = ""
    while true do
        local s = uart.read(uart_id,1)
		
        if s == "" then
			--uart.on(uart_id,"receive",function() sys.publish("UART_RECEIVE") end)

            if not sys.waitUntil("UART_RECEIVE", 35000/uart_baud) then

                if cacheData:len()>0 then
                    local a,_ = string.toHex(cacheData)
                    log.info("modbus 接收数据", a)

					local data = string.sub(cacheData, 4)

                    local _, temperature, humidity = pack.unpack(data, ">H2")
                    local values = {
                        temperature = temperature / 10, 
                        humidity = humidity / 10,
                    }
					
                    local payload = json.encode(values)
					log.info("采集到数据", payload)

                    local imei = misc.getImei()
                    mqttOutMsg.publish("/up/property/incubator/"..imei, payload)


                    cacheData = ""
                end
            end
            --uart.on(uart_id,"receive")

        else
			--log.info("rs485:", string.toHex(s))
            cacheData = cacheData..s
        end
    end
end

--注册串口的数据发送通知函数
uart.on(uart_id,"receive",function() sys.publish("UART_RECEIVE") end)
uart.on(uart_id,"sent", function() 
	--uart.set_rs485_oe(uart_id, pio.P0_23, 0)
	--uart.on(uart_id,"receive",function() sys.publish("UART_RECEIVE") end)
	-- log.info("uart sent", "123")
end)

--配置并且打开串口
uart.setup(uart_id,uart_baud,8,uart.PAR_NONE,uart.STOP_1, nil, 1)
--485使能
--pins.setup(23,0)
--uart.set_rs485_oe(uart_id, pio.P0_23, 1, 1, 1)
uart.set_rs485_oe(uart_id, pio.P0_0, 1, 1, 1)

--启动串口数据接收任务
sys.taskInit(modbus_read)

require"mqttOutMsg"
require"misc"


sys.taskInit(function ()

	sys.wait(5000)

    while true do
		modbus_send(1, 3, 0, 2)
        
        sys.wait(5000)
    end
end)

