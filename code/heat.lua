heat_light_lim=heat_light_lim or 100
heat_timer_num=heat_timer_num or 1
heat_timer_int=heat_timer_int or 1000
heat_mqtt_topic=heat_mqtt_topic or "/heat"
heat_mqtt_id=heat_mqtt_id or node.chipid()
heat_mqtt_port=heat_mqtt_port or 1883
heat_node_room=heat_node_room or "home"
heat_node_alias=heat_node_alias or heat_mqtt_id
heat_mqtt_state=0
heat_light_cur=0
heat_temp_cur=0
heat_humi_cur=0
heat_fast_left=0
heat_prof_cur="NORMAL"
heat_env_state="ATHOME"

if file.exists("cfg/heat-cfg.lua") then dofile("cfg/heat-cfg.lua") end

local cache_light_cur, cache_light_lim, cache_light_state, cache_node_room, cache_node_alias, cache_temp_cur, cache_humi_cur

local function heat_read_temp()
  local status, temp, humi

  if brd_dht then
    status,temp,humi=dht.readxx(brd_dht)
    if status ~= dht.OK or temp < -40 or temp > 80 then
      status,temp,humi=dht.readxx(brd_dht)
    end
    if status ~= dht.OK or temp < -40 or temp > 80 then
      status,temp,humi=dht.readxx(brd_dht)
    end
    if status == dht.OK and temp >= -40 and temp <= 80 then
      heat_temp_cur=temp
      heat_humi_cur=humi
    end
  end
end

function heat_read_light()
  heat_light_cur=adc.read(0)
end

local function heat_setup_pwm()
  if brd_pwm then
    pwm.setup(brd_pwm,1000,1023)
    pwm.start(brd_pwm)
  end
end

function heat_write_pwm(v)
  if brd_pwm then
    pwm.setduty(brd_pwm,v)
  end
end

function heat_light_state()
  return (heat_light_cur >= heat_light_lim) and 1 or 0
end

function heat_compute_profile()
  local state=heat_env_state
  local profile_name
  local prev_prof=heat_prof_cur

  if     state==nil      then state="ATHOME"
  elseif state=="WAKEUP" then state="MORNING"
  elseif state=="BACK"   then state="EVENING"
  end
  profile_name="heat_p_" .. state .. ((heat_light_state() > 0) and "_LIT" or "_DRK")
  if _G[profile_name]==nil then
    heat_prof_cur="NORMAL"
  else
    heat_prof_cur=_G[profile_name]
  end

  if heat_prof_cur == "ECO" then
    heat_fast_left=(heat_fast_left < 1000) and (heat_fast_left+1) or 1000
  elseif heat_fast_left > 0 then
    heat_fast_left=heat_fast_left-1
    heat_prof_cur="FAST"
  end
end

function heat_compute_pwm()
  local ret
  if _G["heat_pwm_"..heat_prof_cur]==nil then
    ret=500
  else
    ret=_G["heat_pwm_"..heat_prof_cur]
  end
  if heat_humi_cur < 70 then return ret end
  if heat_prof_cur == "ECO" then return ret end
  return (ret >= 100) and (ret - 100) or 0
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
  s:subscribe({
    [heat_mqtt_topic .. "/env/+"]=0,
    [heat_mqtt_topic .. "/cmd/" .. heat_mqtt_id .. "/+"]=0},
    nil)
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

  --print("topic " .. t .. " value " .. v)
  if t == heat_mqtt_topic .. "/env/state" then heat_env_state=v end

  if t:sub(1,pfxlen) ~= heat_mqtt_topic .. "/cmd/" .. heat_mqtt_id .. "/" then return end
  if v == nil then return end

  if name == "light_lim" then heat_light_lim=tonumber(v)
  end
end

heat_setup_pwm()

heat_mqtt=mqtt.Client((heat_mqtt_idpfx or "") .. heat_mqtt_id, 10, nil, nil)
heat_mqtt:lwt(heat_mqtt_topic .. "/sts/" .. heat_mqtt_id .. "/online", "", 0, 1)
heat_mqtt:on("message", mqtt_message_cb)
heat_mqtt:on("offline", mqtt_disconnect_cb)

heat_mqtt_reconnect()

tmr.alarm(heat_timer_num,heat_timer_int,tmr.ALARM_SEMI,function()
  local led
  if brd_led then
    -- flash the led ON in ECO, or OFF in normal
    led = heat_prof_cur == "ECO"
    led = (brd_led_inv and not led) or (not brd_led_inv and led)
    gpio.write(brd_led, led and 1 or 0)
  end
  heat_read_light()
  heat_read_temp()
  heat_compute_profile()
  heat_write_pwm(heat_compute_pwm())

  if cache_light_cur ~= heat_light_cur then cache_light_cur = heat_pub("/light_cur", heat_light_cur) end
  if cache_light_lim ~= heat_light_lim then cache_light_lim = heat_pub("/light_lim", heat_light_lim) end
  if cache_light_state ~= heat_light_state() then cache_light_state = heat_pub("/light_state", heat_light_state()) end
  if cache_prof_cur ~= heat_prof_cur then cache_prof_cur = heat_pub("/prof_cur", heat_prof_cur) end
  if cache_temp_cur ~= heat_temp_cur then cache_temp_cur = heat_pub("/temp_cur", heat_temp_cur) end
  if cache_humi_cur ~= heat_humi_cur then cache_humi_cur = heat_pub("/humi_cur", heat_humi_cur) end
  if cache_node_room ~= heat_node_room then cache_node_room = heat_pub("/room", heat_node_room) end
  if cache_node_alias ~= heat_node_alias then cache_node_alias = heat_pub("/alias", heat_node_alias) end
  tmr.start(heat_timer_num)
  if brd_led then
    led = heat_prof_cur == "ECO"
    led = (brd_led_inv and not led) or (not brd_led_inv and led)
    gpio.write(brd_led, led and 0 or 1)
  end
end)
