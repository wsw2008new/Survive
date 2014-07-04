local Map = require "script/map"
local Que = require "script/queue"
local Avatar = require "script/avatar"
local Rpc = require "script/rpc"

local game = {
	id,
	maps,
	freeidx,
}

function game_init(id)
	game.id = id
	game.maps = {}
	local que = Que.Queue()
	for i=1,65535 do
		que:push({v=i,__next=nil})
	end
	game.freeidx = que
end


Rpc.RegisterRpcFunction("EnterMap",function (rpcHandle)
	print("EnterMap")
	if true then
		Rpc.RPCResponse(rpcHandle,nil,"failed")
		return
	end
	local param = rpcHandle.param
	local mapid = param[1]
	local maptype = param[2]
	local plys = param[3]
	local gameids
	if not mapid then
		--创建实例
		mapid = game.freeidx:pop()
		if not mapid then
			--通知group,gameserver繁忙
			rpcResponse(rpcHandle,nil,"busy")
		else
			local map = Map.NewMap():init(mapid,maptype)
			game.maps[mapid] = map
			gameids = map:entermap(rpk)
			if gameids then
				--通知group进入地图失败
				Rpc.rpcResponse(rpcHandle,nil,"failed")
			end
		end
	else
		local map = game.maps[mapid]
		if not map then
			--TODO 通知group错误的mapid(可能实例已经被销毁)
			Rpc.rpcResponse(rpcHandle,nil,"instance not found")
		else
			gameids = map:entermap(rpk)
			if not gameids then
				--通知group进入地图失败
				Rpc.rpcResponse(rpcHandle,nil,"failed")
			end
		end
	end
	--将成功进入的mapid返回给调用方
	Rpc.rpcResponse(rpcHandle,{mapid,gameids},nil)	
end)

Rpc.RegisterRpcFunction("LeaveMap",function (rpcHandle)
	local param = rpcHandle.param
	local mapid = param[1]
	local map = game.maps[mapid]
	if map then
		local plyid = rpk_read_uint16(rpk)
		if map:leavemap(plyid) then
			Rpc.rpcResponse(rpcHandle,mapid,nil)
			if map.plycount == 0 then
				--没有玩家了，销毁地图
				map:clear()
				game.que:push({v=mapid,__next=nil})
				game.maps[mapid] = nil				
			end
		else
			Rpc.rpcResponse(rpcHandle,nil,"failed")
		end
	else
		Rpc.rpcResponse(rpcHandle,nil,"failed")
	end	
end)

--[[
Rpc.RegisterRpcFunction("DestroyMap",function (rpcHandle)
	local param = rpcHandle.param
	local mapid = param[1]
	local map = game.maps[mapid]
	if map then
		map:clear()
		game.que:push({v=mapid,__next=nil})
		game.maps[mapid] = nil
		rpcResponse(rpcHandle,mapid,nil)
	else
		rpcResponse(rpcHandle,nil,"failed")
	end	
end)]]--


local function CS_MOV(_,rpk,conn)
	local mapid = rpk_read_uint16(rpk)
	local map = game.maps[mapid]
	if map then
		local plyid = rpk_read_uint16(rpk)
		local ply = map.avatars[plyid]
		if ply and ply.avattype == Avatar.type_player then
			local x = rpk_read_uint16(rpk)
			local y = rpk_read_uint16(rpk)
			ply:mov(x,y)
		end
	end
end


local function reg_cmd_handler()
	C.reg_cmd_handler(CMD_CS_MOV,{handle=CS_MOV})	
end

return {
	RegHandler = reg_cmd_handler,
}


