heat_light_lim=heat_light_lim or 100
heat_timer_num=heat_timer_num or 1
heat_timer_int=heat_timer_int or 1000
heat_mqtt_topic=heat_mqtt_topic or "/heat"
heat_mqtt_id=heat_mqtt_id or node.chipid()
heat_mqtt_port=heat_mqtt_port or 1883
heat_node_room=heat_node_room or "home"
heat_node_alias=heat_node_alias or heat_mqtt_id
heat_pwm_night=heat_pwm_night or 1023
heat_pwm_day=heat_pwm_day or 1023
heat_mqtt_state=0
heat_light_cur=0
heat_temp_cur=0
heat_humi_cur=0

local cache_light_cur, cache_light_lim, cache_light_state, cache_node_room, cache_node_alias, cache_temp_cur, cache_humi_cur

function heat_read_temp()
  local status, temp, humi
  status,temp,humi=dht.readxx(4)
  if status ~= dht.OK then
    status,temp,humi=dht.readxx(4)
  end
  if status == dht.OK then
    heat_temp_cur=temp
    heat_humi_cur=humi
  end
end

function heat_read_light()
  gpio.mode(0,0)
  gpio.mode(5,1)
  gpio.write(5,0)
  heat_light_cur=adc.read(0)
end

function heat_set_pwm(v)
  pwm.setup(7,1000,v)
  pwm.start(7)
end

function heat_light_state()
  return (heat_light_cur >= heat_light_lim) and 1 or 0
end

function heat_pub(t,v)
  if heat_mqtt == nil then return nil end
  if heat_mqtt_state == 0 then heat_mqtt_reconnect() end
  if heat_mqtt_state < 2 then return nil end
  heat_mqtt:publish(heat_mqtt_topic .. "/sts/" .. heat_mqtt_id .. t, v, 0, 1)
  return v
end

local function mqtt_connect_cb(s)
  heat_mqtt_state=2
  s:subscribe(heat_mqtt_topic .. "/cmd/" .. heat_mqtt_id .. "/+",0,nil)
  s:publish(heat_mqtt_topic .. "/sts/" .. heat_mqtt_id .. "/online", "1", 0, 1)
end

local function mqtt_fail_cb(s,r)
  heat_mqtt_state=0
end

local function mqtt_disconnect_cb(s)
  heat_mqtt_state=0
end

function heat_mqtt_reconnect()
  if heat_mqtt_host == nil then heat_mqtt_state = 0 return end
  if heat_mqtt_state > 0 then return end
  if heat_mqtt:connect(heat_mqtt_host, heat_mqtt_port, 0, 1, mqtt_connect_cb, mqtt_fail_cb) then
    heat_mqtt_state = 1
  end
end

local function mqtt_message_cb(s,t,v)
  local pfxlen=string.len(heat_mqtt_topic)+string.len(heat_mqtt_id)+6
  local name=t:sub(pfxlen+1)
  if t:sub(1,pfxlen) ~= heat_mqtt_topic .. "/cmd/" .. heat_mqtt_id .. "/" then return end
  if v == nil then return end

  if     name == "pwm_day"   then heat_pwm_day=tonumber(v)
  elseif name == "pwm_night" then heat_pwm_night=tonumber(v)
  elseif name == "light_lim" then heat_light_lim=tonumber(v)
  end
end

heat_mqtt=mqtt.Client((heat_mqtt_idpfx or "") .. heat_mqtt_id, 10, nil, nil)
heat_mqtt:lwt(heat_mqtt_topic .. "/sts/" .. heat_mqtt_id .. "/online", "", 0, 1)
heat_mqtt:on("message", mqtt_message_cb)
heat_mqtt:on("offline", mqtt_disconnect_cb)

heat_mqtt_reconnect()

tmr.alarm(heat_timer_num,heat_timer_int,tmr.ALARM_SEMI,function()
  heat_read_light()
  heat_read_temp()
  heat_set_pwm((heat_light_state() > 0) and heat_pwm_day or heat_pwm_night)
  if cache_light_cur ~= heat_light_cur then cache_light_cur = heat_pub("/light_cur", heat_light_cur) end
  if cache_light_lim ~= heat_light_lim then cache_light_lim = heat_pub("/light_lim", heat_light_lim) end
  if cache_light_state ~= heat_light_state() then cache_light_state = heat_pub("/light_state", heat_light_state()) end
  if cache_temp_cur ~= heat_temp_cur then cache_temp_cur = heat_pub("/temp_cur", heat_temp_cur) end
  if cache_humi_cur ~= heat_humi_cur then cache_humi_cur = heat_pub("/humi_cur", heat_humi_cur) end
  if cache_node_room ~= heat_node_room then cache_node_room = heat_pub("/room", heat_node_room) end
  if cache_node_alias ~= heat_node_alias then cache_node_alias = heat_pub("/alias", heat_node_alias) end
  tmr.start(heat_timer_num)
end)
