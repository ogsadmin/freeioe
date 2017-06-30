local skynet = require 'skynet'
local snax = require 'skynet.snax'
local log = require 'utils.log'
local class = require 'middleclass'
local mc = require 'skynet.multicast'
local dc = require 'skynet.datacenter'

local api = class("APP_MGR_API")

function api:initialize(app_name, mgr_snax, cloud_snax)
	self._app_name = app_name
	self._mgr_snax = mgr_snax or snax.uniqueservice('appmgr')
	self._cloud_snax = cloud_snax or snax.uniqueservice('cloud')
end

function api:data_dispatch(channel, source, cmd, app, sn, ...)
	--log.trace('Data Dispatch', channel, source, cmd, app, sn, ...)
	local f = self._handler['on_'..cmd]
	if f then
		return f(app, sn, ...)
	else
		log.trace('No handler for '..cmd)
	end
end

function api:ctrl_dispatch(channel, source, ...)
	log.trace('Ctrl Dispatch', channel, source, ...)
	local f = self._handler.on_ctrl
	if f then
		return f(...)
	else
		log.trace('No handler for on_ctrl')
	end
end

function api:comm_dispatch(channel, source, ...)
	log.trace('Comm Dispatch', channel, source, ...)
	local f = self._handler.on_comm
	if f then
		return f(...)
	else
		log.trace('No handler for on_comm')
	end
end

function api:set_handler(handler, watch_data)
	self._handler = handler
	local mgr = self._mgr_snax

	if handler then
		self._data_chn = mc.new ({
			channel = mgr.req.get_channel('data'),
			dispatch = function(channel, source, ...)
				self.data_dispatch(self, channel, source, ...)
			end
		})
		if watch_data then
			self._data_chn:subscribe()
		end
	else
		if self._data_chn then
			self._data_chn:unsubscribe()
			self._data_chn = nil
		end
	end

	if handler then
		self._ctrl_chn = mc.new ({
			channel = mgr.req.get_channel('ctrl'),
			dispatch = function(channel, source, ...)
				self.ctrl_dispatch(self, channel, source, ...)
			end
		})
		if handler.on_ctrl then
			self._ctrl_chn:subscribe()
		end
	else
		if self._ctrl_chn then
			self._ctrl_chn:unsubscribe()
			self._ctrl_chn = nil
		end
	end

	if handler then
		self._comm_chn = mc.new ({
			channel = mgr.req.get_channel('comm'),
			dispatch = function(channel, source, ...)
				self.comm_dispatch(self, channel, source, ...)
			end
		})
		if handler.on_comm then
			self._comm_chn:subscribe()
		end
	else
		if self._comm_chn then
			self._comm_chn:unsubscribe()
			self._comm_chn = nil
		end
	end
end

--[[
-- List devices
-- @param app: default is "*"
--]]
function api:list_devices(app)
	return dc.get('DEVICES')
end

function api:add_device(sn, props)
	self._data_chn:publish('add_device', self._app_name, sn, props)
	return dc.set('DEVICES', sn, props)
end

function api:mod_device(sn, props)
	self._data_chn:publish('mod_device', self._app_name, sn, props)
	return dc.set('DEVICES', sn, props)
end

function api:del_device(sn)
	self._data_chn:publish('del_device', self._app_name, sn, props)
	return dc.set('DEVICES', sn, props)
end

function api:get_device(sn)
	return dc.get('DEVICES', sn)
end

function api:set_device_ctrl(sn, cmd, params)
	self._ctrl_chn:publish(self._app_name, sn, cmd, params)
end

function api:get_prop_value(sn, prop, type)
	return dc.set('DEVICE', sn, prop, type)
end

function api:set_prop_value(sn, prop, type, value)
	self._data_chn:publish('set_device_prop', self._app_name, sn, prop, type, value)
	return dc.set('DEVICES', sn, prop, type, value)
end

function api:dump_comm(app, dir, ...)
	return self._comm_chn:publish(self._app_name, app, dir, ...)
end

--[[
-- generate device serial number
--]]
function api:gen_sn()
	return self._cloud_snax.req.get_sn()
end

--[[
-- Get device configuration string by device serial number(sn)
--]]
function api:get_conf(sn)
	return self._cloud_snax.req.get_device_conf(sn)
end

--[[
-- Set device configuration string
--]]
function api:set_conf(sn, conf)
	return self._cloud_snax.req.set_device_conf(sn)
end

return api