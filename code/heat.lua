heat_light_lim=heat_light_lim or 685
heat_timer_num=heat_timer_num or 1
heat_timer_int=heat_timer_int or 1000
heat_mqtt_topic=heat_mqtt_topic or "/heat"
heat_mqtt_id=heat_mqtt_id or node.chipid()
heat_mqtt_port=heat_mqtt_port or 1883
heat_node_room=heat_node_room or "home"
heat_node_alias=heat_node_alias or heat_mqtt_id

function heat_read_light()
  gpio.mode(0,0); gpio.mode(5,1); gpio.write(5,0); return adc.read(0);
end

function heat_pub(t,v)
  if heat_mqtt == nil or not heat_mqtt_connected then return end
  heat_mqtt:publish(heat_mqtt_topic .. "/sts/" .. heat_mqtt_id .. t, v, 0, 1)
end

local function mqtt_connect_cb(s)
  heat_mqtt_connected=true
  s:subscribe(heat_mqtt_topic .. "/cmd/" .. heat_mqtt_id .. "/+",0,nil)
end

local function mqtt_disconnect_cb(s)
  heat_mqtt_connected=false
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

heat_mqtt:connect(heat_mqtt_host, heat_mqtt_port, 0, 1, mqtt_connect_cb, nil)

tmr.alarm(heat_timer_num,heat_timer_int,tmr.ALARM_SEMI,function()
  heat_light_cur=heat_read_light()
  heat_pub("/light_cur", heat_light_cur)
  heat_pub("/light_lim", heat_light_lim)
  heat_pub("/light_state", ((heat_light_cur >= heat_light_lim) and 1 or 0)
  heat_pub("/room", heat_node_room)
  heat_pub("/alias", heat_node_alias)
  heat_pub("/online", "1")
  tmr.start(heat_timer_num)
end)
