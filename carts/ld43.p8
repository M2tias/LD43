pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
local vertical_stars = 3
local swarm_cost = 1
local swarm_build_cd = 1.5
local swarm_waypoints = {
		{ x = 0, y = -10 },
		{ x = 4, y = -7 },
		{ x = 6, y = -3 },
		{ x = 4, y = 10 },
		{ x = 0, y = 16 },
		{ x = -8, y = 10 },
		{ x = -10, y = -3 },
		{ x = -8, y = -7 },
	}
local swarm_sx = 2
local swarm_sy = 2
local swarm_s = 1
local swarm_built_time = time()
--enemy types
local enemy_tiny = 0
local enemy_normal = 1
local enemy_boss = 2
local enemy_rock = 3
--level types
local space = 0
--state
local intro = 0
local newlevel = 1
local game = 2
local gameover = 3
local win = 4
local gamestate = intro
local dead_reason = ""

local currentlevel = 0
local currentwave = 0
local levels = {
	{ --level 1
		waves = { --wave 1
			{
				{ x = 130, y = 50, type = enemy_rock }
			},
			{
				{ x = 120, y = 20, type = enemy_tiny },
				{ x = 140, y = 20, type = enemy_tiny },
				{ x = 160, y = 20, type = enemy_tiny },
				{ x = 180, y = 20, type = enemy_tiny }
			},
			{
				{ x = 130, y = 40, type = enemy_rock },
				{ x = 130, y = 70, type = enemy_rock }
			},
			{
				{ x = 120, y = 90, type = enemy_tiny },
				{ x = 140, y = 90, type = enemy_tiny },
				{ x = 160, y = 90, type = enemy_tiny },
				{ x = 180, y = 90, type = enemy_tiny }
			},
			{
				{ x = 130, y = 40, type = enemy_normal },
				{ x = 130, y = 70, type = enemy_normal }
			}
		},
		type = space
	},
	{ --level2
		waves = {
			{
				{ x = 130, y = 40, type = enemy_rock },
				{ x = 130, y = 70, type = enemy_rock },
				{ x = 250, y = 50, type = enemy_rock },
				{ x = 350, y = 70, type = enemy_rock },
				{ x = 400, y = 80, type = enemy_rock },
				{ x = 580, y = 20, type = enemy_rock },
				{ x = 580, y = 60, type = enemy_rock }
			},
			{
				{ x = 130, y = 40, type = enemy_normal },
				{ x = 130, y = 70, type = enemy_normal }
			},
			{
				{ x = 120, y = 40, type = enemy_tiny },
				{ x = 140, y = 40, type = enemy_tiny },
				{ x = 160, y = 40, type = enemy_tiny },
				{ x = 200, y = 40, type = enemy_tiny },
				{ x = 128, y = 85, type = enemy_normal }
			},
			{
				{ x = 130, y = 20, type = enemy_normal },
				{ x = 130, y = 40, type = enemy_normal },
				{ x = 130, y = 60, type = enemy_normal },
				{ x = 130, y = 80, type = enemy_normal }
			},
			{
				{ x = 130, y = 30, type = enemy_rock },
				{ x = 130, y = 65, type = enemy_rock },
				{ x = 200, y = 90, type = enemy_rock },
				{ x = 200, y = 70, type = enemy_rock },
			},
			{
				{ x = 130, y = 5, type = enemy_normal },
				{ x = 150, y = 55, type = enemy_normal },
				{ x = 130, y = 80, type = enemy_normal },
				{ x = 135, y = 30, type = enemy_tiny },
				{ x = 155, y = 30, type = enemy_tiny },
				{ x = 140, y = 70, type = enemy_tiny },
				{ x = 160, y = 70, type = enemy_tiny }
			},
			{
				{ x = 230, y = 50, type = enemy_boss }
			}
		},
		type = space
	}
}

local fade = 0 --big to small
local explode = 1 --small to big and gone
local fadeinout = 2

local targetsound = true
local charging = false
local chargetime = 0
local chargesound = false
local enemies = {}
local point_star_field = {}
local explosions = {}
local enemy_bullets = {}
local drops = {}
local player = {
	x = 10,
	y = 50,
	ship_parts = 1,
	hp = 10,
	bullets = {},
	swarm = {},
	w = 32, --these should be tiles or other w/h should not be...
	h = 16,
	target = nil,
	target_enemy = nil,
	target_ei = -1,
	iframe = true,
	ifstarted = time(),
	ifduration = 1
}

local beam_starting = false
local beam_starting_duration = 1.5
local beam_starting_started = 0
local beam_duration = 3
local beam_on = false
local beam_started = 0
local nextlvlx = 128
local bosseffectx = 128
local start_normal_music = false
local normal_music_started = false
local start_boss_effect = false
local boss_effect_started = false

function _init()
	init_starfield()
end

function _update()
	if gamestate == intro then
		if btnp(4) or btnp(5) then
			gamestate = newlevel
			music(6)
		end
	elseif gamestate == win then
		music(-1)
		if btnp(4) or btnp(5) then
			--gamestate = intro
			run()
			return
		end
	elseif gamestate == gameover then
		music(-1)
		if btnp(4) or btnp(5) then
			--gamestate = intro
			run()
			return
		end
	elseif gamestate == newlevel then
		if nextlvlx > -40 then
			nextlvlx = nextlvlx - 2
		else
			bosseffectx = 128
			currentlevel = currentlevel + 1
			boss_effect_started = false
			currentwave = 0
			gamestate = game
			music(0)
		end
	elseif gamestate == game then
		if #enemies == 0 then
			currentwave = currentwave + 1

			if currentlevel > #levels then
				gamestate = win
				return
			else
				local wave = levels[currentlevel].waves[currentwave]
				if wave == nil then
					gamestate = newlevel
					nextlvlx = 128
					music(6)
					return
				end

				for i = 1, #wave do
					local enemy = wave[i]
					create_enemy(enemy.type, enemy.x, enemy.y)
				end
			end
		end
		update_player()
		update_bullets()
		update_starfield()
		update_swarm()
		update_enemies()
		update_targeting()
		update_explosions()
		update_drops()

		local sacrifice_targets = {}
		for e = 1, #enemies do
			local enemy = enemies[e]
			if enemy.sacrifice then
				add(sacrifice_targets, enemy)
			end
		end

		if player.hp <= 0 then
			gamestate = gameover
			dead_reason = "your carrier was destroyed"
			return
		elseif #player.swarm + player.ship_parts < #sacrifice_targets then
			gamestate = gameover
			dead_reason = "no more ships to sacrifice"
			return
		end

		if #enemies == 1 then
			if enemies[1].type == enemy_boss and enemies[1].x > 100 then
				bosseffectx = bosseffectx - 1
				start_normal_music = false
				if not boss_effect_started then
					start_boss_effect = true
				end
			elseif enemies[1].type == enemy_boss and not normal_music_started then
				start_normal_music = true
			end
		end
	end
end

function _draw()
	if gamestate == intro then
		cls()
		spr(64, 24, 0, 10, 4)
		print("you are fighting against", 8, 36, 6)
		print("a hostile alien race.", 8, 46, 6)
		print("stun the enemies with z", 8, 60, 6)
		print("kill them by sacrificing", 8, 70, 6)
		print("with x", 8, 80, 6)
		print("destroy rocks to get", 8, 100, 3)
		print("ship building resources", 8, 110, 3)
		print("press x or z to play", 26, 122, 8)
	elseif gamestate == win then
		cls()
		print("you win!", 50, 40, 11)
		print("restart by pressing z or x", 20, 70, 6)
	elseif gamestate == gameover then
		cls()
		print("game over", 48, 40, 8)
		print(dead_reason, 10, 50, 8)
		print("restart by pressing z or x", 10, 70, 6)
	elseif gamestate == newlevel then
		cls()
		print("!! caution !!", 128-nextlvlx, 50, 8)
		print("level " .. (currentlevel+1), nextlvlx, 60, 12)
		print("!! caution !!", 128-nextlvlx, 70, 8)
	elseif gamestate == game then
		cls()
		draw_starfield()
		draw_swarm()
		draw_player()
		draw_bullets()
		draw_enemies()
		draw_targeting()
		draw_drops()
		draw_explosions()
		draw_gui()
		--print(currentlevel, 0, 0, 10)
		--print(currentwave, 0, 10, 10)
		--print(#levels[curresntlevel].waves[1][1], 0, 20, 10)
		--print(#enemies, 0, 30, 10)
		--print(start_normal_music, 0, 40, 10)
		--print(brrrrrr, 0, 50, 10)
		
		if #enemies == 1 then
			if enemies[1].type == enemy_boss and enemies[1].x > 130 then
				
				print("!! caution !!", 128-bosseffectx, 50, 8)
				print("massive organic creature incoming", bosseffectx, 60, 12)
				print("!! caution !!", 128-bosseffectx, 70, 8)
			end
		end

		if start_boss_effect then
			music(6)
			start_boss_effect = false
			boss_effect_started = true
		elseif start_normal_music then
			music(0)
			start_normal_music = false
			normal_music_started = true
		end
	end
end

--------------------------
--player
function update_player()
	if btn(1) then
		player.x = player.x + 2
	elseif btn(0) then
		player.x = player.x - 2
	end
	
	if btn(2) then
		player.y = player.y - 1
	elseif btn(3) then
		player.y = player.y + 1
	end

	if btn(4) then
		charging = true
		chargetime = chargetime + 1/30
		if not chargesound and chargetime < 1 then
			if chargetime >= 1 then
			elseif chargetime >= 0.1 then
				chargesound = true
				sfx(2, 3)
			end
		elseif chargesound and chargetime >= 1 then
			chargesound = false
			--sfx(3, 3)
		end
	else
		if chargesound then
		end
		charging = false
		if chargetime > 0.01 then
			sfx(-1, 3)
			sfx(4, 3)
			chargesound = false
			local bx = player.x + 27
			local by = player.y + 7
			add(player.bullets, {
				x = bx,
				y = by,
				damage = flr(chargetime*4+1.5),
				dead = false
			})
		end
		chargetime = 0
	end

	if btn(5) then
		if #player.swarm > 0 and player.target_enemy ~= nil then
			local freeships = {}
			for f = 1,#player.swarm do
				local ship = player.swarm[f]
				if not ship.target_enemy then
					add(freeships, ship)
				end
			end

			local enemy = enemies[player.target_ei]
			--no assigned target yet, good to go
			if not enemy.targeted then
				local si = flr(rnd(#freeships))+1
				local ship = freeships[si]
				if ship ~= nil then
					ship.nextwp = { x = player.target_enemy.x, y = player.target_enemy.y }
					enemy.targeted = true
					player.target_enemy.targeted = true
					ship.refwp = enemy --references are hard
					ship.target_enemy = true
				end
			end
		end
	end
	
	create_swarm_ship()

	if chargetime > 1 then
		chargetime = 1
	end

	if time() - player.ifstarted > player.ifduration then
		player.iframe = false
	end
end

function draw_player()
	local px = player.x
	local py = player.y
	if player.iframe and flr(time()*10)%2 == 0 then
		whitepal(true)
		spr(17, px, py, 4, 2)
		whitepal(false)
	else
		spr(17, px, py, 4, 2)
	end
	if charging then
		local minlen = 8+chargetime*10
		local mult = 8-chargetime*7
		local len = 18
		local col = 8
		if chargetime < 1 then
			len = minlen+sin(time()*4)*mult
			col = 9+flr(sin(time()*2+0.5)*2)
		end
		line(px+11, py+10, px+11+len, py+10, col) --normal gun charging line
	end
	spr(49+(time()*4)%2, px-1, py+7)
	spr(51+(time()*5)%2, px+1, py+7)
end

--------------------------
--swarm
function update_swarm()
	local sacrifice = {}
	for s = 1, #player.swarm do
		local ship = player.swarm[s]
		
		if ship.refwp.type ~= nil then
			sfx(1, 2)
		end

		--if target_enemy and the ship reaches it kill the enemy
		if ship.target_enemy then
			if abs(ship.x - ship.nextwp.x) < 4 then -- better distance constant thing
				if abs(ship.y - ship.nextwp.y) < 4 then
					del(enemies, ship.refwp)
					add(sacrifice, ship)
					local e_x = ship.refwp.x + (ship.refwp.w*8)/2
					local e_y = ship.refwp.y + (ship.refwp.h*8)/2
					create_explosion(e_x, e_y, ship.refwp.type)

					--if rnd() <= ship.refwp.drop then
					--	add(drops, { x = e_x, y = e_y })
					--end
					sfx(-1, 2)
					sfx(6, 2)
				end
			end
		elseif abs(ship.x - ship.nextwp.x) < swarm_sx then
			if abs(ship.y - ship.nextwp.y) < swarm_sy then
				-- wp reached, get a new one
				local nextwpi = 1
				for i = 1,#swarm_waypoints do
					if swarm_waypoints[i] == ship.refwp then nextwpi = i+1 end
				end
				if nextwpi > #swarm_waypoints then
					nextwpi = 1
				end
				ship.nextwp.x = swarm_waypoints[nextwpi].x + player.x + rnd(4)
				ship.nextwp.y = swarm_waypoints[nextwpi].y + player.y + rnd(2)
				ship.refwp = swarm_waypoints[nextwpi]
			end
		end

		local direction = normalize(sub(ship.nextwp, ship))
		local vel = mult(direction, swarm_s)
		local new_pos = sum(ship, vel)
		ship.x = new_pos.x
		ship.y = new_pos.y
	end

	for i = 1, #sacrifice do
		local ship = sacrifice[i]
		del(player.swarm, ship)
	end
end

function update_in_swarm()
end

function update_to_swarm()
end

function create_swarm_ship()
	if player.ship_parts <= 0 then
		return
	end
	
	if time()-swarm_built_time < swarm_build_cd then
		return
	end

	swarm_built_time = time()
	player.ship_parts = player.ship_parts - swarm_cost
	local wpx = player.x + swarm_waypoints[1].x
	local wpy = player.y + swarm_waypoints[1].y
	add(player.swarm, {
		x = player.x+10,
		y = player.y-1,
		nextwp = { x = wpx, y = wpy },
		-- reference to the actual waypoint so it can be found on the list
		refwp = swarm_waypoints[1],
		target_enemy = false,
		dead = false
	})
end

function draw_swarm()
	for s = 1,#player.swarm do
		local ship = player.swarm[s]
		if not ship.dead then
			spr(1, ship.x, ship.y)
		end
	end
end

--------------------------
--targeting

function update_targeting()
	local closest_x = 1000
	local closest_enemy = nil
	local closest_enemy_i = -1
	for i = 1, #enemies do
		local enemy = enemies[i]
		local frame = enemy.sprites[1]
		if (player.y + (player.h / 2)) > enemy.y and
			(player.y + (player.h / 2)) < (enemy.y + frame.h*8) then
			
			if enemy.hp <= 0 then
				if enemy.x < closest_x and enemy.x > player.x then
					closest_x = enemy.x
					closest_enemy = enemy
					closest_enemy_i = i
				end
			end
		end
	end

	if closest_enemy ~= nil then
		local frame = closest_enemy.sprites[1]
		local target_x = closest_enemy.x
		local target_y = closest_enemy.y + (frame.h*8 - 4) / 2

		player.target = { x = target_x, y = target_y }
		player.target_enemy = closest_enemy
		player.target_ei = closest_enemy_i
	else
		player.target = nil
		player.target_enemy = nil
		player.target_ei = -1
	end
end

function draw_targeting()
	if player.target ~= nil then
		-- don't if the ship was sent
		if player.target_enemy.targeted then
			sfx(-1, 3)
			targetsound = false
			return
		end

		if flr((time() * 12) % 2) == 0 then
			spr(2, player.target.x, player.target.y)
		end
		if flr((time() * 6) % 2) == 0 then
			print("!!press x to send a fighter!!", 4, 0, 8)
			if not targetsound then
				sfx(5, 3)
				targetsound = true
			end
		end
	elseif targetsound then
		sfx(-1, 3)
		targetsound = false
	end
end

--------------------------
--bullets
function update_bullets()
	update_player_bullets()
	update_enemy_bullets()
end

function update_enemy_bullets()
	for i = 1, #enemy_bullets do
		local bullet = enemy_bullets[i]
		bullet.x = bullet.x + bullet.dx
		bullet.y = bullet.y + bullet.dy

		if not player.iframe then
			if bullet.x > player.x + 4 and --don't count the rear jet
				bullet.x < player.x + player.w-2 and--a bit easier collision
				bullet.y > player.y + 1 and --top tiles are not that important
				bullet.y < player.y + player.h-4 then --again a bit easier
				player.hp = player.hp - 1
				sfx(8, 2)
				player.iframe = true
				player.ifstarted = time()
			end
		end
	end
end

function update_player_bullets()
	local delete = {}
	local kill = {}
	for i = 1, #player.bullets do
		local bullet = player.bullets[i]
		bullet.x = bullet.x + 3
		if bullet.x > 130 then
			add(delete, bullet)
			break
		end

		--collision check
		for e = 1,#enemies do
			local enemy = enemies[e]
			local eframe = enemy.sprites[1] -- animation meh
			local spos = spritesheetpos(eframe.sprite)
			local sw = eframe.w*8
			local sh = eframe.h*8
			local ex = enemy.x
			local ey = enemy.y
			local bgc = 0
			if enemy.hp <= 0 and enemy.dbg ~= nil then
				bgc = enemy.dbg
			elseif enemy.dbg ~= nil then
				bgc = enemy.bg
			end
			--bullet hit pos
			local bhx = bullet.x + 8
			local bhy = bullet.y + 4
			
			if bhx >= ex and
				bhy >= ey and
				bhx <= ex+sw and
				bhy <= ey+sh and
				not enemy.iframe
			then
				sshx = bhx-ex --spritesheet hit pos
				sshy = bhy-ey
				local hit = false
				for j = 0,4 do
					local c = sget(sshx+j, sshy)
					if c ~= bgc then
						hit = true
					end
				end

				if hit then
					bullet.dead = true
					add(delete, bullet)
					enemy.hp = enemy.hp - bullet.damage
					sfx(0)
					if enemy.hp <= 0 then
						if not enemy.sacrifice then -- check for hp also
							add(kill, enemy)
							local e_x = enemy.x + (enemy.w*8)/2
							local e_y = enemy.y + (enemy.h*8)/2
							create_explosion(e_x, e_y, enemy.type)

							if enemy.type == enemy_rock then
								add(drops, { x = e_x, y = e_y })
							end

							sfx(-1, 2)
							sfx(6, 2)
						else
							--enemy is stunned, can be checked from the hp
						end
					end
				end
			end
		end
	end

	for i = 1, #delete do
		del(player.bullets, delete[i])
	end

	for e = 1, #kill do
		del(enemies, kill[e])
	end
end

function draw_bullets()
	for i = 1, #player.bullets do
		local bullet = player.bullets[i]
		if not bullet.dead then
			if bullet.damage == 5 then
				spr(4, bullet.x, bullet.y)
			else
				spr(3, bullet.x, bullet.y)
			end
		end
	end

	for i = 1, #enemy_bullets do
		local bullet = enemy_bullets[i]
		spr(44, bullet.x, bullet.y)
	end
end

--------------------------
--stars and background
function init_starfield()
	for x = 0, 64 do
		for s = 1, vertical_stars do
			add(point_star_field, {
				x = x*2,
				y = rnd(126)+1
			})
		end
	end
end

function update_starfield()
	for s = 1, vertical_stars do
		del(point_star_field, point_star_field[1])

		add(point_star_field, {
			x = 128,
			y = rnd(126)+1
		})
	end
end

function draw_starfield()
	for s=1,#point_star_field do
		local star = point_star_field[s]
		if star ~= nil then
			pset(flr(s/3)*2, star.y, 1)
		end
	end
end

--------------------------
--enemies
--drop is the chance to drop ship materials
--  >1 drop rate means there's a chance to drop >1 materials

function update_enemies()
	deleted = {}
	for e = 1,#enemies do
		local enemy = enemies[e]
		if enemy.type == enemy_boss then
			update_boss(enemy)
		elseif enemy.type == enemy_normal then
			update_enemy_normal(enemy)
		elseif enemy.type == enemy_tiny then
			update_enemy_tiny(enemy)
		elseif enemy.type == enemy_rock then
			update_enemy_rock(enemy)
		end

		if not player.iframe then
			local ehx = enemy.x + enemy.w/2
			local ehy = enemy.y + enemy.h/2
			if ehx > player.x + 4 and --don't count the rear jet
				ehx < player.x + player.w-2 and--a bit easier collision
				ehy > player.y + 1 and --top tiles are not that important
				ehy < player.y + player.h-4 then --again a bit easier
				player.hp = player.hp - 1
				sfx(8, 2)
				player.iframe = true
				player.ifstarted = time()
			end
		end
		if enemy.x < -8 then
			add(deleted, enemy)
		end
	end

	for i=1,#deleted do
		del(enemies, deleted[i])
	end
end

function update_enemy_tiny(enemy)
	if enemy.x > enemy.active_x then
		enemy.x = enemy.x - 2
		enemy.iframe = true
		return
	else
		enemy.iframe = false
	end

	if enemy.hp <= 0 then
		return
	end

	enemy.y = enemy.y + sin(enemy.x/32)
	enemy.x = enemy.x - 0.75
end

function update_enemy_normal(enemy)
	if enemy.x > enemy.active_x then
		enemy.x = enemy.x - 1
		enemy.iframe = true
		return
	else
		enemy.iframe = false
	end

	if enemy.hp <= 0 then
		return
	end

	enemy.y = enemy.y + sin(time())

	if time() - enemy.shot > enemy.shootcd then
		enemy.shot = time()
		for i = 1,enemy.bullets do
			add(enemy_bullets, { x = enemy.x, y = enemy.y+4, dx = -1, dy = 2-i  })
		end
	end
end

function update_enemy_rock(enemy)
	if enemy.x > enemy.active_x then
		enemy.x = enemy.x - 1
		enemy.iframe = true
		return
	else
		enemy.iframe = false
	end

	if enemy.hp <= 0 then
		return
	end

	enemy.y = enemy.y + sin(time()) * 0.1
	enemy.x = enemy.x - 1
end

function update_boss(enemy)
	if enemy.x > enemy.active_x then
		enemy.x = enemy.x - 0.33
		return
	else
		enemy.iframe = false
	end

	if enemy.hp <= 0 then
		beam_on = false
		beam_starting = false
		return
	end

	if enemy.y < 10 then
		enemy.movedown = true
	elseif enemy.y > 90 then
		enemy.movedown = false
	elseif rnd() > 0.95 then
		enemy.movedown = not enemy.movedown
	end

	if enemy.movedown then
		enemy.y = enemy.y + 0.5
	else
		enemy.y = enemy.y - 0.5
	end

	if beam_on and not player.iframe then
		if player.y + 4 < enemy.y+13 and
			player.y + player.h > enemy.y+12 then
			player.hp = player.hp - 1
			sfx(8, 2)
			player.iframe = true
			player.ifstarted = time()
		end
	end

	-- beam has 2% chance to start and stays off for at least as long as it was on
	if not beam_starting and rnd() > 0.75 and (time() - beam_started > beam_duration) then
		beam_starting = true
		beam_starting_started = time()
	end

	if beam_starting and (time() - beam_starting_started > beam_starting_duration) then
		beam_on = true
		beam_started = time()
		beam_starting = false
		beam_starting_started = time()
	end

	if beam_on and (time() - beam_started > beam_duration) then
		beam_on = false
		beam_started = time()
	end

	if time() - enemy.shot > enemy.shootcd then
		enemy.shot = time()
		for i = 1,enemy.bullets do
			add(enemy_bullets, { x = enemy.x, y = enemy.y+10, dx = -1, dy = -1.5+i*0.5  })
		end
	end
end

function draw_enemies()
	for e = 1,#enemies do
		local enemy = enemies[e]
		local frames = enemy.sprites
		local frame = frames[1]
		local bgc = 0
		if enemy.bg ~= nil then bgc = enemy.bg end

		if enemy.animrate > 0 then
			frame = frames[flr((time()*enemy.animrate)%#frames)+1]
		end
		if enemy.iframe then
			palt(0, false) palt(bgc, true)
			if flr(time()*10)%2 == 0 then
				whitepal(true)
				spr(frame.sprite, enemy.x, enemy.y, frame.w, frame.h)
				whitepal(false)
			else
				spr(frame.sprite, enemy.x, enemy.y, frame.w, frame.h)
			end
			palt(bgc, false) palt(0, true)
		elseif enemy.hp > 0 then
			palt(0, false) palt(bgc, true)
			spr(frame.sprite, enemy.x, enemy.y, frame.w, frame.h)
			palt(bgc, false) palt(0, true)
		elseif enemy.dsprite > -1 then
			if enemy.dw < enemy.w or enemy.dh < enemy.h then
				palt(0, false) palt(bgc, true)
				spr(frame.sprite, enemy.x, enemy.y, frame.w, frame.h)
				palt(bgc, false) palt(0, true)			
			end

			if enemy.dbg ~= nil then bgc = enemy.dbg end
			palt(0, false) palt(bgc, true)
			spr(enemy.dsprite, enemy.x + enemy.ddx, enemy.y + enemy.ddy, enemy.dw, enemy.dh)
			palt(bgc, false) palt(0, true)
		end

		if enemy.type == enemy_boss then
			if beam_on then
				line(0, enemy.y+12, enemy.x+4, enemy.y+12, 10)
				line(0, enemy.y+13, enemy.x+4, enemy.y+13, 10)
			elseif beam_starting then
				line(enemy.x+4-rnd(5), enemy.y+12, enemy.x+4, enemy.y+12, 10)
				line(enemy.x+4-rnd(5), enemy.y+12, enemy.x+4, enemy.y+12, 10)
			end
		end
	end
end

function create_enemy(type, x, y)
	if type == enemy_tiny then
		create_tiny_enemy(x, y)
	elseif type == enemy_normal then
		create_normal_enemy(x, y)
	elseif type == enemy_boss then
		create_boss(x, y)
	elseif type == enemy_rock then
		create_rock_enemy(x, y)
	end
end

function create_tiny_enemy(x, y)
	add(enemies, {
		x = x, 
		y = y,
		w = 1,
		h = 1,
		hp = 1,
		sacrifice = false,
		shoots = false,
		bullets = 1,
		shootcd = 100,
		shot = 0, --time of last shoot
		drop = 0.1,
		type = enemy_tiny,
		animrate = 2.5,
		active_x = 120,
		sprites = {
			{
				sprite = 14,
				w = 1,
				h = 1
			},
			{
				sprite = 15,
				w = 1,
				h = 1
			}
		},
		-- stunned
		dsprite = -1, --no stun sprite
		ddx = 0,
		ddy = 0,
		dw = 1,
		dh = 1,
		--always false in the beginning
		--true if a swarm ship was sent
		targeted = false
	})
end

function create_normal_enemy(x, y)
	add(enemies, {
		x = x, 
		y = y,
		w = 2,
		h = 2,
		hp = 2,
		bg = 15, --transparent color
		sacrifice = true,
		shoots = true,
		bullets = 3,
		shootcd = 2,
		active_x = 80+flr(rnd(30)),
		shot = 0, --time of last shoot
		drop = 0.9,
		type = enemy_normal,
		animrate = -1, --no animation yet
		sprites = {
			{
				sprite = 6,
				w = 2,
				h = 2
			}
		},
		-- stunned
		dsprite = 38,
		dbg = 15, --transparent color
		ddx = 0,
		ddy = 0,
		dw = 2,
		dh = 2,
		--always false in the beginning
		--true if a swarm ship was sent
		targeted = false
	})
end

function create_boss(x, y)
	add(enemies, {
		x = x, 
		y = y,
		w = 4,
		h = 4,
		hp = 20,
		sacrifice = true,
		shoots = true,
		bullets = 5,
		shootcd = 1.5,
		shot = 0, --time of last shoot
		drop = 2,
		type = enemy_boss,
		animrate = -1,
		active_x = 90,
		sprites = {
			{
				sprite = 8,
				w = 4,
				h = 4
			}
		},
		-- stunned
		dsprite = 12,
		dbg = 15, --transparent color
		ddx = 0,
		ddy = 8,
		dw = 2,
		dh = 2,
		iframe = true,
		--always false in the beginning
		--true if a swarm ship was sent
		targeted = false
	})
end

function create_rock_enemy(x, y)
	add(enemies, {
		x = x, 
		y = y,
		w = 2,
		h = 2,
		hp = 5,
		bg = 0, --transparent color
		sacrifice = false,
		shoots = false,
		bullets = 0,
		shootcd = 100,
		active_x = 120,
		shot = 0, --time of last shoot
		drop = 1,
		type = enemy_rock,
		animrate = -1, --no animation yet
		sprites = {
			{
				sprite = 30,
				w = 2,
				h = 2
			}
		},
		-- stunned
		dsprite = 30,
		dbg = 15, --transparent color
		ddx = 0,
		ddy = 0,
		dw = 2,
		dh = 2,
		--always false in the beginning
		--true if a swarm ship was sent
		targeted = false
	})
end

--------------------------
--drops

function update_drops()
	local taken = {}
	for d = 1, #drops do
		local drop = drops[d]

		drop.x = drop.x - 0.5
		drop.y = drop.y + sin(time()*1.5)
		
		if drop.x > player.x + 4 and --don't count the rear jet
			drop.x < player.x + player.w-2 and--a bit easier collision
			drop.y > player.y + 1 and --top tiles are not that important
			drop.y < player.y + player.h-4 then --again a bit easier
			player.ship_parts = player.ship_parts + 1
			add(taken, drop)
			sfx(7, 3)
		end
	end

	for d = 1,#taken do
		del(drops, taken[d])
	end
end

function draw_drops()
	for d = 1, #drops do
		local drop = drops[d]

		spr(60+time()%2, drop.x, drop.y)
	end
end

--------------------------
--explosions

function draw_explosions()
	for i = 1,#explosions do
		local explosion = explosions[i]
		for j = 1,#explosion.particles do
			local p = explosion.particles[j]
			local time_passed = time() - p.started
			local time_end = p.started + p.length
			if p.type == fade then
				local percentage = 1-time_passed/p.length
				circfill(p.x, p.y, p.r * percentage, p.c)
			elseif p.type == explode then
				local percentage = time_passed/p.length
				circfill(p.x, p.y, p.r * percentage, p.c)
			else
				circfill(p.x, p.y, p.r, p.c)
			end
		end
	end
end

function update_explosions()
	local deleted = {}
	for i = 1,#explosions do
		local deletedp = {}
		local explosion = explosions[i]
		for j = 1,#explosion.particles do
			local p = explosion.particles[j]
			local time_passed = time() - p.started
			if time_passed > p.length then
				add(deletedp, p)
			end
		end

		for d = 1, #deletedp do
			local p = explosion.particles[d]
			del(explosion.particles, p)
		end

		if time() - explosion.started > explosion.length then
			add(deleted, explosion)
		end
	end

	for d = 1, #deleted do
		local e = explosions[d]
		del(explosions, e)
	end
end

function create_explosion(x, y, type)
	local length = 1
	local rate = 1
	local r = 3

	if type == enemy_tiny then
		length = 0.2
		rate = 100
		r = 3
	elseif type == enemy_normal then
		length = 0.5
		rate = 0.25
		r = 5
	elseif type == enemy_boss then
		length = 2
		rate = 0.333
		r = 8
	elseif type == enemy_rock then
		length = 1
		rate = 0.333
		r = 6
	end

	add(explosions, {
		x = x,
		y = y,
		started = time(),
		length = length,
		particles = {
			{ 
				x = x, y = y, 
				r = r, c = 10, 
				started = time(), 
				length = length, 
				type = fade, 
				rate = rate 
			}
		}
	})
end

--------------------------
--gui

function draw_gui()
	rectfill(0, 116, 126, 126, 1) --long bar
	--hp
	local hpx = 0
	line(hpx, 110, hpx, 115, 1) -- label rounding line
	rectfill(hpx+1, 109, hpx+8, 116, 1)
	line(hpx+9, 109, hpx+9, 115, 1) -- label slope lines
	line(hpx+10, 110, hpx+10, 115, 1)
	line(hpx+11, 112, hpx+11, 115, 1)
	line(hpx+12, 114, hpx+12, 115, 1)
	rectfill(1, 117, 30, 125, 0) -- 30 pixels, 3 pixels / hp with 10 hp
	for i=0,(player.hp-1) do
		line(1+i*3, 117, 1+i*3, 125, 8)
		line(2+i*3, 117, 2+i*3, 125, 8)
		line(3+i*3, 117, 3+i*3, 125, 2)
	end
	print("hp", hpx+2, 110, 12)

	-- ship parts
	local spx = 35
	local width = 19
	line(spx, 110, spx, 115, 1) -- label rounding line
	rectfill(spx+1, 109, spx+1+width, 116, 1)
	line(spx+2+width, 109, spx+2+width, 115, 1) -- label slope lines
	line(spx+3+width, 110, spx+3+width, 115, 1)
	line(spx+4+width, 112, spx+4+width, 115, 1)
	line(spx+5+width, 114, spx+5+width, 115, 1)
	rectfill(spx+1, 117, spx+width+5, 125, 0)
	print("parts", spx+2, 110, 12)
	print(player.ship_parts, spx+4, 119, 12)

	-- swarm
	local swpx = 65
	local width = 19
	line(swpx, 110, swpx, 115, 1) -- label rounding line
	rectfill(swpx+1, 109, swpx+1+width, 116, 1)
	line(swpx+2+width, 109, swpx+2+width, 115, 1) -- label slope lines
	line(swpx+3+width, 110, swpx+3+width, 115, 1)
	line(swpx+4+width, 112, swpx+4+width, 115, 1)
	line(swpx+5+width, 114, swpx+5+width, 115, 1)
	rectfill(swpx+1, 117, swpx+width+5, 125, 0)
	print("swarm", swpx+2, 110, 12)
	print(#player.swarm, swpx+4, 119, 12)

	-- power
	local ppx = 95
	local width = 20
	line(ppx, 110, ppx, 115, 1) -- label rounding line
	rectfill(ppx+1, 109, ppx+1+width, 116, 1)
	line(ppx+2+width, 109, ppx+2+width, 115, 1) -- label slope lines
	line(ppx+3+width, 110, ppx+3+width, 115, 1)
	line(ppx+4+width, 112, ppx+4+width, 115, 1)
	line(ppx+5+width, 114, ppx+5+width, 115, 1)
	rectfill(ppx+1, 117, ppx+width+1, 125, 0)
	print("power", ppx+2, 110, 12)
	if charging then
		rectfill(ppx+1, 117, ppx+1+width*chargetime, 125, 8)
	end
	

end

--------------------------
--utils

function sub(a, b)
	if type(b) == "number" then
		return { x = a.x - b, y = a.y - b }
	elseif type(b) == "table" then
		return { x = a.x - b.x, y = a.y - b.y }
	end
end

function sum(a, b)
	if type(b) == "number" then
		return { x = a.x + b, y = a.y + b }
	elseif type(b) == "table" then
		return { x = a.x + b.x, y = a.y + b.y }
	end
end

function mult(a, b)
	if type(b) == "number" then
		return { x = a.x * b, y = a.y * b }
	elseif type(b) == "table" then
		return { x = a.x * b.x, y = a.y * b.y }
	end
end

function normalize(v)
	local mag = magnitude(v)
	return { x = v.x / mag, y = v.y / mag }
end

function magnitude(v)
	return sqrt(v.x*v.x + v.y*v.y)
end

function dot(v1, v2) 
	return v1.x*v2.x + v1.y*v2*y
end

function spritesheetpos(sprite)
	return { x = sprite % 16, y = flr(sprite / 16)}
end

function whitepal(doit)
	if doit then
		for i = 1,15 do
			pal(i, 7)
		end
	else
		for i = 1,15 do
			pal(i, i)
		end
	end
end

__gfx__
0000000000000000000000000000000000000c1080000008ffffffffffffffff00000000000000000000000000000000f3bfffff333333330000000000000000
000000000000000000080000000000000000ccc100000000ffffffffffffffff033333000000000000000000000300003ffbfff331bbb3330000333000000000
00700700001d0000008080000000a980000c07c100000000ffffffffffffffff0300033300000000000000000003b000fffbfff31b313bb13bbb30003bbb3333
000770000111cc1008000800aaaa99821c7777c100000000fff13331ffbbbbff00000003300000000000000000003b00ffffbb3bbb13111b833b0000833b3330
00077000011d111008080800000a9880000c07c100000000ffb113113b3b33bf00000000330000000000b333b0033b00fff300b0033333313333333033330000
00700700011d000008000800000000000000ccc100000000fb361316b3b3b33f00000000033000000003331133331000fb3300300b3b33331133000011333333
000000000dd00000008080000000000000000c1000000000f3333333333333b30000000003300000000b3100111000b0b31333333b11b1b30003300000000000
000000000000000000080000000000000000000080000008ff3300333313331300000000033bbbbb300b310000003b0031230000bb113b130000033000000000
800000080000000000000011d00000000000000080000008ff3033031333111103b0000033333333bbbb300000003000322000000b1011330000000000000000
000000000000000000000010dd0000000000000000000000f33333133111ff3f300b000331bbb33333b33b00000013b032f2000011b133330044999900000000
0000000000000000000000101dd000000000000000000000f331313113ff3f33000b00031b313bb133b3113b00000030f2f811118fb131110444449990000000
00000000000000000000001011dd00000000000000000000ff3111113fff3fff0000bb3bbb13111b333313333b000330f288f8f232b133330444449944999900
000000000000000000000010111dd0000000000000000000fff33ff31fff33ff000322b22333333133333bbb33b03310f283f3f2823bff330444444424499900
0000000000000000dddddd10ddddddddddddd00000000000fff31ff31fffffff0b3382382b3b33333333333333333100ff23f3ff2ffbff330224444424449990
000000001dddddddddddddddddd1d1dcc1c1cd0000000000ff31fff11fffffffb31333333b11b1b33333333333331000fffff3ffffffffff0224442222444490
8000000810101d1d1d1d1d1d1d1d1111111dddd080000008ff3fffffffffffff31033333bb113b133333333333331100ffffffffffffffff0022222662224440
8000000810101111111111111111cc1cccc1c1d080000008ffffffffffffffff3100333b1b101133333333333311310000000000800000080002226666224440
000000001010111111111111111111111111111000000000ffffffffffffffff33033130b0b13333333333111133110000000000000000000005566666622400
000000001010111111100000000000000000000000000000ffffffffffffffff0303030030b131111111111311111000000000000000000000555ddd66d00000
0000000010101111ddddddddddddddddddddddd000000000fff11311ffbbbbff0303030030b1333311111111111110000008e0000000000000555dddddd00000
0000000010101111111111111111111111111dd000000000ffb163613b3b33bf03030300303b0033000011333110000000028000000000000055ddddd1100000
00000000101011111111111111111111111111d000000000fb366366b3b3b33f00030300300b0033300000113300000000000000000000000000d11111000000
000000001111111111111111111111111111110000000000f3332233333333b30000030000000000333000001330000000000000000000000000011100000000
800000080000000011111111111111111111100080000008ff320003331333130000000000000000033300000130000300000000800000080000000000000000
800000080000000000000000000000000000000080000008ff30002313331111000000000000000000310000003300030000000000aaaa008000000880000008
000000008989000008890000800000000080000000000000f33302133111ff3f0000000000000000003100000003003100000000000000000000000000000000
00000000099a000089aa0000009000008900000000000000f331313113ff3f330000000000333300033000000003303100ddbb00a0ddbb0a0000000000000000
00000000088a0000098a0000080000000800000000000000ff3111113fff3fff0000000003311333330000000000331000133b00a0133b0a0000000000000000
0000000089aa0000089a000000a0000080a0000000000000fff33ff31fff33ff0000000003300000000000000000000000113300a011330a0000000000000000
00000000089a0000898a00008800000009a0000000000000fff31ff31fffffff0000000003110000000000000000000000111000a011100a0000000000000000
000000000000000000000000000000000000000000000000ff31fff11fffffff0000000000000000000000000000000000000000000000000000000000000000
800000080000000000000000000000000000000080000008ff3fffffffffffff000000000000000000000000000000000000000000aaaa008000000880000008
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccccccc000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011c1111100c00000000000
000000bbbbb00000000000000000000000000000000000000bbb0000000000000000000000000000000000000000000000000000001c000000100c0000000000
0000bbbbbbbbb00000000000000000000000000000000000b000b000000000000000000000000000000000000000000000000000010c0000000100c000000000
000bbb00000bbb000000000000000000000000000000000b0000000000000000000000000000000000000000000000000000000001c00000000010c000000000
000bb0000000bbb00000000000000000000000000000000b0000000000000000000000000000000000000000000000000000000010c000000000100c00000000
00bb00000000bbb000000000000000000000000000b0000b00000b000000000000000000000000000000000000000000000000001c0000000000010c00000000
00bb0000000bbb00000bbbb0000bbbb000b0bbb00000000b0000000000bbbb0000bbbb00000000000000000000000000000000010c0000000000010c00000000
00bb000000bbb00000bb00bb00bb00bb00bb000b00b000bbbb000b000bb00bb00bb00bb000000000000000000000000000000001c00000000000010c00000000
000b0000000000000bb0000b00b0000000b0000000b0000b00000b000b0000000b0000b000000000000000000000000000000010c00000000000010c00000000
000bb000000000000b00000b00b0000000b0000000b0000b00000b000b0000000bbbbbb00000000000000000000000000000001c000000000000010c00000000
0000bbb0000000000b0000bb00b0000000b0000000b0000b00000b000b0000000b0000000000000000000000000000000000010c000000000000010c00000000
00000bbbbb0000000bb00bbb00bb00bb00b0000000b0000b00000b000bb00bb00bb00bb0000000000000000000000000000001c0000000000000010c00000000
000000bbbbbb000000bbbb0b000bbbb000b0000000b0000b00000b0000bbbb0000bbbb00000000000000000000000000000010c000000000000001c000000000
00000000bbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000010c000000000
0000000000bbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000010c000000000000001c0000000000
00b00000000bbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000010c0000000000
00b000000000bbb0000000333333000000000000000000000000000003000000000000000000000000000000000000000010c000000000000001c00000000000
00bb00000000bbb000003330000330000033330003033300030333000000033330003033300000000000000000000000001c000000000000001c000000000000
000bb000000bbbb000033000000033000330033003300030033000300300330033003300030000000000000000000000010c00000000000001c0000000000000
0000bbbbbbbbbb000033000000000000330000300300000003000000030030000300300000000000000000000000000001c0000000000000cc00000000000000
000000bbbbbbb0000030000000000000300000300300000003000000030033333300300000000000000000000000000010c00000000000cc0000000000000000
000000000000000003300000000000003000033003000000030000000300300000003000000000000000000000000000100ccccccccccc000000000000000000
00000000000000000300000000000000330033300300000003000000030033003300300000000000000000000000000001111111111100000000000000000000
00000000000000000300000000000000033330300300000003000000030003333000300000000000000000000000000000000000000000000000000000000000
00000000000000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000003300000003300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000333000033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000003333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000100000001000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000001000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000001000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000010000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000100000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000100000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000010000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000010000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000100000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000100000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000001000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000001000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000010000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000010000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000100000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000100000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000001000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000001000000000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000060708090a0b0c0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000010203040000161718191a1b1c1d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000111213140000262728292a2b2c2d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000212223240000060738393a3b3c3d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010001313233340000161748494a4b4c4d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000056575806075b5c5d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000100000000000066676816176b6c6d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000767778797a7b7c7d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000c000090200f0200e6201162014620126200f2201d2201f2201f2201d2200d6200362002620194201a4201b3201a32019320000000000000000000000000000000000000000000000000000000000000
010300000061001600056000560002600066000360001600046000160000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
01040000061210712108121091210a1210b1210c1210d1210e1210f121101211112112121131211412115121161211712118121191211a1211b1211c1211d1211e1211f121201212112122121231212412100000
0110000c1e0101f0112001121011200111f0111e0111f0112001121011200111f0110000000001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
010200000000100001066510b051076510f0511b05125051390511800101001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
000a00062951001500005002951000500295002951029500295002951000500005002951000500005002951024500005000050000500005000050000500005000050000500005000050000500005000050000500
010400003863029630186300d6200a620086120461204612026120161202612066020560004600036000d6000860006600076000660004600046000c600000000000000000000000000000000000000000000000
000600001b04015130260300d1302d040221003510022100001003410034100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00040000356500a6500505035600376003f600396003a60016600186001b6001e6002060024600236002a60036600006000060000600006000e60000600006000060000600006000060000600006000060000600
011000000015500155001550015500155001550015500155071550715507155071550715507155071550715503155031550315503155031550315503155031550515505155051550515505155051550515505155
011000000c0630000000000000000c6150c06300000000000c0630000000000000000c61500000000000c06300000000000c06300000246150c06300000246150c06300000000000000024615000000c06300000
011000000015500000001550000000155001550000000000071550715507155071550000007155000000715503155031550315503155031550315503155031550515505155000000515505155000000515500000
011000000c0630000000000000000c6150c06300000000000c0630000000000000000c61500000000000c06300000000000c06300000246150c06300000246150c06300000000000000030615246152461524615
0103000001020030210502107021090210b0210e02110021120211402116021180211a0211b0211d0211e0211f0211d0211b02119021170211402112021100210e0210c0210a0210802106021040210202101021
__music__
01 090a4344
00 090a4344
00 410c4344
00 0b0a4344
00 0b0a4344
02 410c4344
03 0d424344

