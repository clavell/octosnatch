pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
---- main ----
function _init()
	import("art.png")
	fmag=1
	sinkv=.5 drag=0.9

	debug = false
	
	gamestate = {}
	gamestate.level = 2
	gamestate.stage = 1
	gamestate.stage_clear = false
	gamestate.total_num_stage = 2
	stage_data = {}
	stage_data[1] = {babies = 1, dolph = 1, dolph_time = 2, dolph_speed = 0.4}
	music(12)
	
	type = {}
	type.octo  = 1
	type.dolph = 2
	type.plant = 3
	type.fish  = 4
	type.baby  = 5
	type.squid  = 6
	actors = {}
	
	timer = 0
	trans = {}
	trans.r = 0
    trans.moving_in = true
	transitioning = false
	transitioning_to = 0
	
	maincamera = {}
	maincamera.x = 0
	maincamera.rightedge = 128
	maincamera.rightedge_max = 128 * 8
	maincamera.leftedge = 0
	maincamera.buf = 48
	maincamera.speed = 1
	maincamera.fixed = true

	console = { x = 5, y = 100, w = 118, h = 20}
	console.on = false
	console.done = false
	console.msg = {}
	console.fishtype = 2
	console.log = function(msg)
		console.msg = {}
		add(console.msg, msg)
	end

	console.log_rect = function(label, r)
		console.log(label .. ":(" .. flr(r.x) .. "," .. flr(r.y) .. "," .. flr(r.w) .. "," .. flr(r.h) .. ")")
	end

	console.display = function()
		-- background and text
		rectfill(console.x, console.y, console.x + console.w, console.y + console.h, 0)
		rect(console.x, console.y, console.x + console.w, console.y + console.h, 7)
		print(console.msg[1], console.x + console.h + 2, console.y + 2, 7)
		-- response text
		print("ok", console.x + console.h + 2, console.y + console.h - 7, 9)
		circfill(console.x + console.h + 15, console.y + console.h - 5, 3, 9)
		print("x", console.x + console.h + 14, console.y + console.h - 7, 7)
		-- headshot
		rectfill(console.x, console.y, console.x + 20 - 1, console.y + 20, 12)
		rect(console.x, console.y, console.x + 20 - 1, console.y + 20, 7)
		head = fishdict[console.fishtype]
		sspr(head.x, head.y, head.w, head.w, console.x + 3, console.y + 1, 20 - 4, 20 - 2)
	end

	console.clear = function()
		console.msg = {}
	end

	octo = make_player()
	octostate = {}
	octostate.chill    = 1
	octostate.midup    = 2
	octostate.up       = 3
	octostate.snatch   = 4
	octostate.hold     = 5
	octostate.holdpush = 6	
	octo.octostate = octostate.chill

	wavetimer = 0
	octotimer = 0
	
	bub = {}
	bub.x = -30
	bub.y = -30
	bub.time = 0
	bub.delta = 0.1

	hold = {}
	hold.time = 0
	hold.delta = 0.2
	
	dolph = make_actor(type.dolph,-64,64,8*5,8*2,true)
	dolph.delta = 4	-- for animation
	dolph.speed = 0.4
	dolphcue(dolph.x, dolph.y, 0.4)

	squid = make_actor(type.squid, 46, -64, 8*5, 8*3, false)
	squid.speed = 2
	-- display state
	squidstate = {}
	squidstate.close    = 1
	squidstate.halfclose= 2
	squidstate.open     = 3
	squidstate.charge   = 4
	squidstate.launch   = 5
	squid.state = squidstate.close
	-- behaviour
	squidmood = {}
	squidmood.intro 	= 1
	squidmood.flex 		= 2
	squidmood.open 		= 3
	squidmood.dashright = 4
	squidmood.dashleft 	= 5
	squidmood.dying 	= 6
	squid.mood = squidmood.intro
	-- critical screen points
	squidpoints = {}
	squidpoints.left = {x=12,y=70}
	squidpoints.right = {x=46,y=70}

	fishcreate(3 * 10,8)
	fishdict = {} -- fishtype, sprite coordinate
	fishdict[1] = {x = 8*8, y = 2*8, w = 6}
	fishdict[2] = {x = 10*8, y = 2*8, w = 6}
	fishdict[3] = {x = 12*8, y = 2*8, w = 5}
	fishdict[4] = {x = 13*8, y = 2*8, w = 5}
	fishdict[5] = {x = 14*8, y = 2*8, w = 8}
	fishdict[6] = {x = 15*8, y = 4*8, w = 8} -- actually dolphin

	plantcreate(5 * 10)

	babycreate(1,1,0)
end

function make_player()
	local octo=make_actor(type.octo,60,30,16,24,false)
	octo.vx=0
	octo.vy=0
	octo.topvy=.75
	octo.topvx=1
	octo.push=0
	octo.maxpush=25
	octo.bub=false
	octo.snatchedobj=null
	return octo
end

function make_actor(t,x,y,w,h,r)
	local a={}
	a.type=t
	a.x=x
	a.y=y
	a.w=w
	a.h=h
	a.refl=r
	a.enabled=true
	add(actors,a)
	return a
end

function babycreate(n, level, stage)
	babies={}
	saved_babies={}
	for i=1,n do
		-- spawn babies roughly in the middle
		baby = make_actor(type.baby, (stage*128) + 50 + rnd(28), (level-1)*128 + 60 + rnd(28),7,8*2,false)
		baby.vx=0
		baby.vy=0
		baby.topvy=.75
		baby.topvx=1
		baby.snatched = false
		baby.saved = false

		skintones = {4,9,15}
		hair = {0,4,10}
		baby.skin = skintones[flr(rnd(#skintones)) + 1]
		baby.hair = skintones[flr(rnd(#skintones)) + 1]
		add(babies, baby)
	end
end

function plantcreate(n)
	plants={}
	for i=1,n do
	 --make plants in triplets
		newplant=make_actor(type.plant,
		  rnd(maincamera.rightedge_max), 128-rnd(12),
		  2+rnd(3), 12+rnd(20), true)
		newplant.current_w=newplant.w
		newplant.a=rnd(1)
		newplant.c=11
		add(plants,newplant)
		
		offset=0.15
		for i=0,2 do
			plantbro=make_actor(type.plant,
			  0, newplant.y,
			  newplant.w, newplant.h, true)
			plantbro.a=newplant.a+offset
			plantbro.current_w=newplant.current_w
			if plantbro.a>1 then plantbro.a-=1 end
			plantbro.x=newplant.x-sin(plantbro.a)*plantbro.w
			plantbro.c=11
	
			add(plants,plantbro)
			offset+=offset
		end
		
		plantbro.c=3 --last plant dark green
	end
end

function fishcreate(num_schools, max_n)
	fishes = {}
	for i = 1,num_schools do
		size = flr(max_n/2) + rnd(flr(max_n/2))
		basex = rnd(128 + maincamera.rightedge_max)
		basey = 14 + rnd(56)
		speed = 0.2 + rnd(1)
		fishtype = 1 + flr(rnd(3))
		w=12 h=4
		if(fishtype==2) then w=9 h=7 end
		if(fishtype==3) then w=7 end
		
		for j=1,size do
			newfish=make_actor(type.fish,
				basex+5+rnd(40),
				basey+5+rnd(20),
				w, h, false)
			newfish.fishtype=fishtype
			newfish.speed=speed
			newfish.amp=rnd(0.5)
			add(fishes,newfish)
		end
	end
end

function _update()
	--start screen
	if(gamestate.level==0) then
		if(btn(5)) then --check for x
			transitioning=true
			transitioning_to=1
			music(-1,1500) --fade out
		end
	return
	end

	--gamestate.level 1
	if(gamestate.level==1) then
		if (console.on) then
			-- update console box
			if (btn(5)) console.on = false
			return
		end
 		
 		-- check for octo collisions
 		prev_octostate=octo.octostate
		octomove()
		if(prev_octostate==octostate.snatch and octo.octostate==octostate.hold) then
			snatch_collisions()
		end

		-- check for snatch release
		if(drop(prev_octostate, octo.octostate)) then
			-- baby drop
			if(octo.snatchedobj.type == type.baby) then
				-- update baby velocity based on octo velocity
				octo.snatchedobj.vx = octo.vx
				octo.snatchedobj.vy = octo.vy
				octo.snatchedobj.snatched = false
				octo.snatchedobj = null
			end
		end

 		if (not(gamestate.stage_clear)) then
			-- check for satchel collisions
			satchel_hit_zone = {x=dolph.x+16, y=dolph.y+6, w=10, h=8, type=type.dolph}
			for baby in all(babies) do
				if(not(baby.snatched)) then
					prev_baby_saved = baby.saved
					collide(satchel_hit_zone, baby)
					-- fresh baby save
					if (not(prev_baby_saved) and baby.saved) then
						sfx(6)
						add(saved_babies, baby)
						dolph.speed = 0.6
					end
				end
			end

			-- check if dolphin is offscreen right
			if (dolph.x > maincamera.rightedge) then
				sfx(0)
				dolph.enabled = false
				gamestate.stage_clear = true
				gamestate.stage += 1
				maincamera.fixed = false
				maincamera.rightedge = (128 * gamestate.stage)
				
				-- clear saved babies, spawn more babies to the right
				for b in all(saved_babies) do
					b.x = -1024
					b.y = -1024
				end
			end
		else -- stage is clear but camera is moving
			maincamera.leftedge = max(maincamera.leftedge, maincamera.x)
			
			-- TODO: cue player to go right

			-- player has entered next stage
			if (maincamera.x >= (128 * (gamestate.stage - 1))) then
				sfx(1)
				maincamera.fixed = true
				gamestate.stage_clear = false
				maincamera.leftedge = 128 * (gamestate.stage - 1)
				dolphcue(maincamera.leftedge - 64, 64 + rnd(32), 0.4)
			end
		end

		if (not(maincamera.fixed)) then cameramove() end
		octocount()
		dolphmove()
		for baby in all(babies) do babymove(baby) end
		for i=1,#fishes do fishmove(fishes[i]) end
	end
	
	--gamestate.level 2
	if(gamestate.level==2) then
		if (console.on) then
			-- update console box
			if (btn(5)) console.on = false
			return
		end
 		
 		prev_octostate=octo.octostate
		octomove()
		squidmove()
		if(prev_octostate==octostate.snatch and octo.octostate==octostate.hold) then
			snatch_collisions()
		end

		if (not(maincamera.fixed)) then cameramove() end
		octocount()
	end

	--todo:endgame
end

function _draw()
	cls()
	camera(0,0)
 
	--start screen
	if(gamestate.level==0) then
		startsplay()
	end
 
	--game
	if(gamestate.level==1) then
		rectfill(0,16,128,128,color(12))
 	
		--everything that scrolls
		camera(maincamera.x,0)
		map(0,2,0,2*8,16*10,15)
		wave()
 	
		for p in all(plants) do plantsplay(p) end
		for f in all(fishes) do fishsplay(f) end
		dolphsplay()
		for b in all(babies) do babysplay(b) end
		octosplay()

		if (console.on) then
			camera(0,0)
			console.display()
		end
	end

	if(gamestate.level==2) then
		rectfill(0,0,128,128,color(0))
 	
		--everything that scrolls
		camera(maincamera.x,0)
		map(0, 16, 0, 0, 16*1, 16)
		
		squidsplay()
		octosplay()

		if (console.on) then
			camera(0,0)
			console.display()
		end
	end
	
	--transition
	if(transitioning) then
		transition(3)
	end
	
end

---- game logic ----
-- snatch collisions
function snatch_collisions()
	snatch_hit_zone = { x=octo.x+2, y=octo.y+16, w=10, h=6, type=type.octo}

	for a in all(actors) do
		if (a.type~=type.octo and a.type~=type.plant) then
   			collide(snatch_hit_zone,a)
		end
 	end
end

function satchel_collisions()
	satchel_hit_zone = {x=dolph.x+16, y=dolph.y+6, w=10, h=8, type=type.dolph}

	for a in all(actors) do
		if (a.type==type.baby) then
   			collide(satchel_hit_zone,a)
		end
 	end
end

function collide(a1, a2)
 	if (a1==a2) then return end
 	local hor = (((a1.x+a1.w) < a2.x) or (a1.x > (a2.x+a2.w)))
 	local vert= (((a1.y+a1.h) < a2.y) or (a1.y > (a2.y+a2.h)))

	local not_colliding = (hor or vert) 
	if (not(not_colliding)) then
		if (collide_event(a1, a2)) return
	end
end

function collide_event(a1,a2)
	-- octo player
	if (a1.type==type.octo) then
		-- baby
		if(a2.type==type.baby) then
			octo.snatchedobj = a2
			a2.snatched = true
			sfx(0)
			return true
		end
	end

	-- dolphin satchel
	if (a1.type==type.dolph) then
		-- baby
		if(a2.type==type.baby) then
			a2.saved = true
			return true
		end
	end

	return false
end

function octocount()
	if (octotimer == 30) then
		octotimer=0
		wavetimer+=2
	else	
		octotimer+=1
	end
	if (wavetimer==16) wavetimer=0
end

function drop(prev_octostate, curr_octostate)
	hold_prev = (prev_octostate==octostate.hold or prev_octostate==octostate.holdpush)
	hold_curr = (curr_octostate==octostate.hold or curr_octostate==octostate.holdpush)
	return ((octo.snatchedobj ~= null) and hold_prev and (not(hold_curr)))
end

---- display ----
-- transition
function transition(speed)
 r1=36+trans.r
 r2=120+trans.r
 tentaclesplay(r1,r2)
 if(trans.moving_in) then
  --tentacles moving in
  trans.r-=speed
  if(trans.r<=-36) then
   --tentacles covering screen
   trans.moving_in=false
   gamestate.level=transitioning_to
   if(gamestate.level==1) music(0,500)
  end
 else
  if(trans.r<64) then
   trans.r+=speed
  else
   --tentacles off screen
   trans.r=0
   trans.moving_in=true
   transitioning=false
  end
 end
end

-- start screen
function startsplay()
 rectfill(0,0,128,128,12)
 print("‡octosnatch‡",36,58,7)
 if(sin(time())<0) then
  print("‡",36,58,8)
  print("‡",128-36-8,58,8)
 end
 print("press x",50,68,0)
 if(btn(5)) print("x",50+24,68,8)
 print("to start",48,74,0)

 r1=36 r2=120
 tentaclesplay(r1,r2)
end

-- octo
function octohead(x,y)
 spr(0,x,y,2,1,octo.refl)
end

function octoheadhigh(x,y)
 spr(2,x,y,2,1,octo.refl)
end

function legsdown()
 spr(0,octo.x,octo.y,2,3,octo.refl)
end

function legshold()
 spr(2,octo.x,octo.y,2,3,octo.refl)
end

function legsmidup()
 octohead(octo.x,octo.y)
 spr(4,octo.x,octo.y+8,2,2,octo.refl)
end

function legsup()
 octohead(octo.x,octo.y)
 spr(6,octo.x-8,octo.y+8,4,2,octo.refl)
end

function legsnatch()
 octoheadhigh(octo.x,octo.y)
 offset=3
 if(octo.refl)offset=5
	spr(10,octo.x-offset,octo.y+8,3,2,octo.refl)
end

function legsholdpush()
 octoheadhigh(octo.x,octo.y)
	spr(13,octo.x-4,octo.y+8,3,2,octo.refl)
end

function snatch()
	t=time()-hold.time
	if(t<hold.delta) then
		legsnatch()
	else
		legshold()
		octo.snatch=false
	end
end

function bubble()
	t=time()-bub.time
	for i=0,3 do
		if(t<bub.delta*i) then
	 	spr(i+36,bub.x-2,bub.y+18,1,1)
			spr(i+36,bub.x+8,bub.y+18,1,1,true)
			spr(i+36,bub.x-2,bub.y+24,1,1)
			spr(i+36,bub.x+8,bub.y+24,1,1,true)
			spr(i+36,bub.x-5,bub.y+24,1,1)
			spr(i+36,bub.x+13,bub.y+24,1,1,true)
			break
		end
	end
end

function octosplay()
	-- debug hit area
	if(debug) then
		snatch_hit_zone={x=octo.x+2,
                  y=octo.y+16,
                  w=10,h=6}
		hitsplay(snatch_hit_zone,9)
 	end

	bubble()
	if(octo.octostate==octostate.chill) legsdown()
	if(octo.octostate==octostate.up) legsup()
	if(octo.octostate==octostate.midup) legsmidup()
	if(octo.octostate==octostate.snatch) legsnatch()
	if(octo.octostate==octostate.hold) legshold()
	if(octo.octostate==octostate.holdpush) legsholdpush()

	--if just released push, start bubbles
	if(octo.bub==true) then
		bub.x=octo.x
		bub.y=octo.y
		bub.time=time()
		octo.bub=false
	end
end

-- baby
function babysplay(baby)
	if(not(baby.enabled)) then return end
	pal(15, baby.skin)
	pal(10, baby.hair)

	if (baby.saved) then
		spr(83,baby.x,baby.y-2,1,1,baby.r)
	else
		spr(83,baby.x,baby.y,1,2,baby.r)
	end
	pal()
end

-- dolphin
function dolphlow()
	sspr(0, 3*8, 5*8, 2*8, dolph.x,dolph.y, 50, 20, dolph.refl)
end
function dolphmid()
	sspr(5*8, 3*8, 5*8, 2*8, dolph.x,dolph.y, 50, 20, dolph.refl)
end
function dolphigh()
	sspr(10*8, 3*8, 5*8, 2*8, dolph.x,dolph.y, 50, 20, dolph.refl)
end

function dolphsplay()
	if (not(dolph.enabled)) then return end
	if ((time()%dolph.delta)<(flr(dolph.delta/4))) then
		dolphlow()
	else
		if ((time()%dolph.delta)<(flr(dolph.delta/2))) then
			dolphmid()
		else
			if ((time()%dolph.delta)<(3*flr(dolph.delta/4))) then
		 	dolphigh()
		 else
		 	dolphmid()
		 end
		end
	end
end

function squidhead(x,y)
	sspr(3*8, 9*8, 2*8, 2*8, x, y, 2*2*8, 2*2*8, squid.refl)
end

function squidchargehead(x,y)
	sspr(3*8 - 4, 9*8, 2*8, 2*(8+1), x, y, 2*2*8, 2*2*(8+1), squid.refl)
end

function squidclose()
	if (squid.refl) then
		squidhead(squid.x, squid.y)
		sspr(0, 9*8, 3*8, 3*8, squid.x + 2*2*8, squid.y, 2*3*8, 2*3*8, squid.refl)
		sspr(3*8, 11*8, 2*8, 1*8, squid.x, squid.y + 2*2*8, 2*2*8, 2*1*8, squid.refl)
	else
		squidhead(squid.x + 2*3*8, squid.y)
		sspr(0, 9*8, 3*8, 3*8, squid.x,squid.y, 2*3*8, 2*3*8, squid.refl)
		sspr(3*8, 11*8, 2*8, 1*8, squid.x + 2*3*8, squid.y + 2*2*8, 2*2*8, 2*1*8, squid.refl)
	end
end

function squidhalfclose()
	if (squid.refl) then
		squidhead(squid.x, squid.y)
		sspr(5*8, 9*8, 3*8, 3*8, squid.x + 2*2*8, squid.y, 2*3*8, 2*3*8, squid.refl)
		sspr(8*8, 9*8, 2*8, 1*8, squid.x, squid.y + 2*2*8, 2*2*8, 2*1*8, squid.refl)
	else
		squidhead(squid.x + 2*3*8, squid.y)
		sspr(5*8, 9*8, 3*8, 3*8, squid.x,squid.y, 2*3*8, 2*3*8, squid.refl)
		sspr(8*8, 9*8, 2*8, 1*8, squid.x + 2*3*8, squid.y + 2*2*8, 2*2*8, 2*1*8, squid.refl)
	end
end

function squidopen()
	if (squid.refl) then
		squidhead(squid.x, squid.y)
		sspr(10*8, 9*8, 3*8, 3*8, squid.x + 2*2*8, squid.y, 2*3*8, 2*3*8, squid.refl)
		sspr(8*8, 10*8, 2*8, 1*8, squid.x, squid.y + 2*2*8, 2*2*8, 2*1*8, squid.refl)
	else
		squidhead(squid.x + 2*3*8, squid.y)
		sspr(10*8, 9*8, 3*8, 3*8, squid.x,squid.y, 2*3*8, 2*3*8, squid.refl)
		sspr(8*8, 10*8, 2*8, 1*8, squid.x + 2*3*8, squid.y + 2*2*8, 2*2*8, 2*1*8, squid.refl)
	end
end

function squidcharge()
	if (squid.refl) then
		squidchargehead(squid.x, squid.y - 2)
		sspr(13*8, 9*8, 3*8, 2*8, squid.x + 2*2*8, squid.y + 2*1*8, 2*3*8, 2*2*8, squid.refl)
		sspr(8*8, 11*8, 1*8, 1*8, squid.x + 2*1*8, squid.y + 2*2*8, 2*1*8, 2*1*8, squid.refl)
	else
		squidchargehead(squid.x + 2*3*8, squid.y - 2)
		sspr(13*8, 9*8, 3*8, 2*8, squid.x,squid.y + 2*1*8, 2*3*8, 2*2*8, squid.refl)
		sspr(8*8, 11*8, 1*8, 1*8, squid.x + 2*3*8, squid.y + 2*2*8, 2*1*8, 2*1*8, squid.refl)
	end
end

function squidlaunch()
	o = {x=12,y=6}
	if (squid.refl) then
		squidchargehead(squid.x + 2, squid.y + 5 - o.y)
		sspr(0, 12*8, 3*8, 2*8, squid.x + 2*1*8, squid.y + 2*2*8 - o.y, 2*3*8, 2*2*8, squid.refl)
	else
		squidchargehead(squid.x + 2*2*8 - 1 + o.x, squid.y + 5 - o.y)
		sspr(0, 12*8, 3*8, 2*8, squid.x + o.x, squid.y + 2*2*8 - o.y, 2*3*8, 2*2*8, squid.refl)
	end
end

function squidsplay()
	if (squid.state == squidstate.close) then squidclose() end
	if (squid.state == squidstate.halfclose) then squidhalfclose() end
	if (squid.state == squidstate.open) then squidopen() end
	if (squid.state == squidstate.charge) then squidcharge() end
	if (squid.state == squidstate.launch) then squidlaunch() end
end

--fishes
function fishsplay(f)
	s=44 w=2
	if(f.fishtype==1) then s=40
	else
		if(f.fishtype==2) then s=42
		else
			w=1
		end
	end
	spr(s,f.x,f.y,w,1)
end

--plants
function plantsplay(p)
 a=p.a
	for i=0,p.h do
		pset(p.x+p.current_w*sin(a),p.y-i,p.c)
		a+=0.04
		if a>1 then a-=1 end
	end
	
	if p.refl then
	 p.current_w-=0.04
	else
	 p.current_w+=0.04
	end
	
	if p.current_w<(p.w/6) then p.refl=false end
	if p.current_w>p.w then p.refl=true end
end

---- movement ----
-- octo --
function octopush()
	if(btn(5)) then
		if(btn(4)) then
			octo.push=min(octo.push+1,octo.maxpush-15)
		else
			octo.push=min(octo.push+1,octo.maxpush)
		end	
	else
		if(octo.push ~= 0) then
		    sfx(3,3)
		    octo.vy-=octo.push*.2
			octo.push=0
			octo.bub=true
		end	                 
	end
end

function octomove()
	--sink
	if (octotimer == 1) octo.vy+=sinkv
	--arrow key movement
	if(btn(0)) octo.vx-=0.2 octo.refl=true
	if(btn(1)) octo.vx+=0.2 octo.refl=false
	if(btn(3)) octo.vy+=fmag
	--push movement
	octopush()
	--limit speed
	if (octo.vx > 0) then
		octo.vx = min(octo.vx, octo.topvx)
		octo.vx -= 0.1
		octo.vx = max(octo.vx, 0)
	else
		octo.vx = max(octo.vx, (-1)*octo.topvx)
		octo.vx += 0.1
		octo.vx = min(octo.vx, 0)
	end
	octo.vy = min(octo.vy,octo.topvy)
	octo.vy = drag*octo.vy
	octo.x+=octo.vx
	octo.y+=octo.vy
	
	-- octostate change
	--pushing and snatching
	if(btn(5) and btn(4)) then
			if(octo.push<5) then
				if(octo.octostate~=octostate.snatch and
				   octo.octostate~=octostate.hold) then
					octo.octostate=octostate.snatch
					hold.time=time()
				end
				--check timer
	   if(abs(time()-hold.time)>=hold.delta) then
		   octo.octostate=octostate.hold
	   end
			else
			 octo.octostate=octostate.holdpush
			end
	-- just pushing
	elseif(btn(5)) then
		octo.octostate=octostate.midup
		if(octo.push>=9) then
		 octo.octostate=octostate.up
		end
	-- just snatching
	elseif(btn(4)) then
		if(octo.octostate~=octostate.snatch and
		   octo.octostate~=octostate.hold and
		   octo.octostate~=octostate.holdpush)
		then
			octo.octostate=octostate.snatch
			hold.time=time()
		end
		--check timer
		if(abs(time()-hold.time)>=hold.delta) then
	 		octo.octostate=octostate.hold
		end
	-- just chillin
	else
		octo.octostate=octostate.chill
	end

	-- check edges
	checkedges(octo)
end

function checkedges(a)
	--right edge
	if(a.x > (maincamera.rightedge - a.w)) then
		a.x = (maincamera.rightedge - a.w)
	end
	
	--left edge
	if(a.x < maincamera.leftedge) a.x = maincamera.leftedge
 
	-- vertical edges
	if(a.y < 0) a.y = 0
	if(a.y > (128 - a.h)) a.y = (128 - a.h)
end

function cameramove()
	-- right edge
	if ((octo.x<(maincamera.rightedge-16)) and (octo.x>(maincamera.x+128-maincamera.buf))) then
		maincamera.x+=maincamera.speed
	end
	maincamera.x=min(maincamera.x,maincamera.rightedge-128)

	-- left edge
	if(octo.x<(maincamera.x+maincamera.buf)) maincamera.x-=maincamera.speed
	maincamera.x=max(maincamera.x,maincamera.leftedge)
end

--dolphin
function dolphcue(x, y, speed)
	dolph.x = x
	dolph.y = y
	dolph.speed = speed
	dolph.enabled = true
end

function dolphmove()
	if (not(dolph.enabled)) then
		dolph.x = -1024
		dolph.y = -1024
	end
	-- generally move towards octo ?
	dolph.x += dolph.speed

	-- swimming animation
	if ((time()%dolph.delta)<(flr(dolph.delta/4))) then
		dolph.y -= 0.15
	else
		if ((time()%dolph.delta)<(flr(dolph.delta/2))) then
			dolph.y -= 0.15
		else
			dolph.y += 0.15
		end
	end
end

-- baby
function babymove(baby)
	if(not(baby.enabled)) then return end
	snatch_hit_zone = {x=octo.x+2, y=octo.y+16, w=10, h=6}
	satchel_hit_zone = {x=dolph.x+16, y=dolph.y+6, w=10, h=8, type=type.dolph}

	if (baby.saved) then
		baby.x = satchel_hit_zone.x + 7
		baby.y = satchel_hit_zone.y - 3
		return
	end

	if(baby.snatched) then
		baby.x = (snatch_hit_zone.x + baby.w / 2)
		baby.y = snatch_hit_zone.y
	else
		--sink
		if (octotimer == 1) baby.vy+=sinkv
		baby.vy = min(baby.vy,baby.topvy)
		baby.vy = drag*baby.vy
		baby.y+=baby.vy
		--drift
		if (baby.vx > 0) then
			baby.vx = min(baby.vx, baby.topvx)
			baby.vx -= 0.015
			baby.vx = max(baby.vx, 0)
		else
			baby.vx = max(baby.vx, (-1)*baby.topvx)
			baby.vx += 0.015
			baby.vx = min(baby.vx, 0)
		end
		baby.x+=baby.vx

		checkedges(baby)
	end
end

--squid
function squidmove()	
	if (squid.mood == squidmood.intro) then
		squid.y += squid.speed
		if (squid.y >= squidpoints.right.y) then
			squid.y = squidpoints.right.y
			squid.mood = squidmood.flex
		end
	end
end

--wave
function wave()
	x=-16
	while(x<maincamera.rightedge) do
		spr(81,x+wavetimer,0,2,2)
		x+=16
	end
end

--fishes
function fishmove(f)
	f.x-=f.speed
	f.y-=f.amp*sin(time())
	if(f.x<-16) then f.x=128+maincamera.rightedge_max end
end

--tentacle display
function tentaclesplay(r1,r2)
 inner_pts={}
 outer_pts={}
 for i=0,7 do
  p1={x=64+r1*cos(i/8),y=64+r1*sin(i/8)}
  p2={x=64+r2*cos(i/8),y=64+r2*sin(i/8)}
  add(inner_pts,p1)
  add(outer_pts,p2)
 end
 
 w=26 l=(r2-r1)
 for i=1,#inner_pts do
  tentacle(outer_pts[i],inner_pts[i],w,l)
 end
end

function tentacle(s,e,w,h)
 --tentacle
 i=0 r=w
 d=dist(s,e)
 if(slope(s,e)!=0) then
  m=(-1/slope(s,e))
 else m=0 end
 
 while(i<h) do
		t=i/d
		p=lerp(s,e,t)
		--math to get perp
		p2 = {x=p.x+1,y=p.y+m}
		v = v_sub(p2,p)
		norm_v = dist(v,{x=0,y=0})
		u = v_mult(v,(1/norm_v))
		--special case when horizontal
		if(s.y==e.y) then
		 if(s.x>e.x) u={x=0,y=-1}
		 if(s.x<=e.x) u={x=0,y=1}
		end
		length = r*sin((i/h/2)+(0.94*time()))
		--to make the upper ones go the right way
		if(s.y<64) length*=(-1)
		widthoffset = v_mult(u,length)
		p = v_add(p,widthoffset)
		circfill(p.x,p.y,r,14)
		i+=2
  if(i%4==0) r-=1
  r=max(r,3)
 end
 
 --suckers
 r=w i=-2 o=18
 while(i<h) do
  i+=1
  if(i%(2*o)==0) then
 		t=i/d
 		p=lerp(s,e,t)
	 	p2={x=p.x+1,y=p.y+m}
 		v = v_sub(p2,p)
	 	norm_v = dist(v,{x=0,y=0})
 		u = v_mult(v,(1/norm_v))
		 -- special case when horizontal
		 if(s.y==e.y) then
		  if(s.x>e.x) u={x=0,y=-1}
		  if(s.x<=e.x) u={x=0,y=1}
	 	end
		 length=r*sin((i/h/2)+(0.94*time()))
 		--to make the upper ones go the right way
	 	if(s.y<64) length*=(-1)
		 widthoffset = v_mult(u,length)
	 	pt = v_add(p,widthoffset)
   if(r>7) then
    circ(pt.x,pt.y,r-5,2)
    circ(pt.x,pt.y,r-6,2)
    circ(pt.x,pt.y,r-7,2)
   end
   r-=(o/3)
   o-=1.5
  end
  r=max(r,3)
 end
end

-- text
function random_fish_text()
	messages = {
		"let me go!",
		"???",
		"what are you doing?",
		"you shouldn't be here",
		"did you hear that noise?"
	}	
	return messages[flr(rnd(#messages)) + 1]
end

--
--helper functions--
function hitsplay(a,c)
 rectfill(a.x,a.y,a.x+a.w,a.y+a.h,c)
end

function lerp(a,b,t)
 local p={}
 p.x = (1-t)*a.x + t*b.x
 p.y = (1-t)*a.y + t*b.y
 return p
end

function dist(a,b)
 return sqrt((b.x-a.x)^2 + (b.y-a.y)^2)
end

function slope(a,b)
 if(a.x==b.x) return 0
 return (b.y-a.y)/(b.x-a.x)
end

function v_add(a,b)
 local result = {}
 result.x = a.x + b.x
 result.y = a.y + b.y
 return result
end

function v_sub(a,b)
 local result = {}
 result.x = a.x - b.x
 result.y = a.y - b.y
 return result
end

function v_mult(v,a)
 local result = {}
 result.x = v.x * a
 result.y = v.y * a
 return result
end

__gfx__
00000000000000000000022222200000002eee2ee2ee200000000000002eee2ee2ee2000000000000000022eeeeeee220000000000000022eeeeeee220000000
0000022222200000000222eeee2000000022eeeeeee22000000000000022eeeeeee220000000000000000022eee8ee2000000000000000022eee8ee200000000
000222eeee2000000002eeeeee22000000022eee8ee200000000000000022eee8ee2000000000000000000022eeee200000000000000000022eeee2000000000
0002eeeeee2200000022eeeeeee20000000022eeee20000000000000000022eeee20000000000000000000022eeee220000000000000000022eeee2200000020
0022eeeeeee20000002eeeeeeeee2000000022eeee22000000000000000022eeee2200000000000000000022eeeee22200000000222000222eeeeee222002220
002eeeeeeeee2000002eeeeeeeee200000022eeeeee2200000000000000022eeeee2200000002220000022eeeeeeeeee220000002e22222eeeeeeeeee2222e20
002eeeeeeeee2000022ee22e22ee20002022eeeeeeee22200000000002222eeeeeee22222222222000022eeeeeeeeeeeee2000002eeeeeeeeeeeeeeeeeeeee20
022ee22e22ee2000002eee2ee2ee2000e22eeeee222ee2220000222222eeeeeeeeeeeeeeeeee22000022eeeee222222ee2e200000222eeeeeeeeeeeeeeee2220
002eee2ee2ee20000022eeeeeee220002eee2eee2e22eee200222eeee22eeeeeeeeeeeeeeee22000022ee2e222000022ee2e200000022eeee22eee22eee22000
0022eeeeeee2200000022eee8ee200002222ee2e2ee222e202222222222eeeeeeeee22222222000002ee2ee2000000022e2e220000000222ee2ee222ee220000
00022eee8ee20000000022eeee2000000022e22e2222022200000000e22e222e2eee22222200000002e22220000000002e2e220000000002ee2eee22e2000000
000022eeee200000000022eeee2200000002222e22000022000000002222202e2eeeeeeee220000002e22020000000002e2e220000000002ee22ee2ee2000000
000022eeee22000000222eeeeee222000000002220000000000000022220002e22eeeeeeee20000002ee200200000000222e2000000000022e2222ee22000000
00022eeeeee22000022eeeeeeeeee2200000000200000000000000222200002202222222222200000022e2000000000220220000000000002220022220000000
0022eeeeeeee220022eeeeeeeeeeee22000000000000000000000000000000000000000000000000000222000000000000220000000000000000000000000000
002eeeee222ee20022eeeeeeeeeeee22000000000000000000000000000000000000000000000000000002200000000002200000000000000000000000000000
002eee2e2e22e2002eeee22eee22eee20000077000000700000000000000000000066666000d0000000000000000000000000000666000000000000000000000
022ee22e2e2222002ee2ee2ee222eee2007707700700700000000007000000000777777667dd000000aa9a000000000009999090a06000000000055550050000
02ee222e2e2022202ee2ee2eee22e2e2007700007070000007000000000000000717777667dd00000aa79aa0a000000099199990006000009090515555550000
02e2202e222002202ee2ee22ee2ee2e20000077007000700000007000000000077776666000d00000a179aaaa000000009999090066606005050555555550000
02222222222002202ee22e2222ee22e2000007700070707000700000700000070000000000000000aaa79aaaa000000000000000661666005555555500050000
022022022000000022ee222002222ee20000000070000700700000070000000000000000000000000aaa9aa0a000000000000000066606000000000000000000
0000000000000000022eee200002ee2000000000000000000007007000007000000000000000000000aa9a000000000000000000000000000000000000000000
00000000000000000002220000222200000000000000000007000000007000000000000000000000000000000000000000000000000000000000000000000000
000000000000000055555555000000000000000000000000000000000555555550000000000000000000000000000000055555555000000000000000aa000000
0000000000000055555566770000000000000000000000000000000555555667700000000000000000000000000000055555566770000000000000000a000000
000000000000555555666000000000000000000000000000000005555556660000000000000000000000000000000555555666000000000000000500aa000000
0000000004455555566600000000000000000000000000000044555555666000000000000000000000000000004455555556600000000000000555000a000000
0000005555445555555555500000000000000000000005555554455555555555000000000000000000000555555445555555555500000000055550000a000000
000055555554445555555555550000000000000000005555555544455555555555500000000000000000555555554555555555555545555555550050aaa00000
000555555555544555555555554500000000000000005515555555555555555555545000000000000000551555555555555555444445555555555550a0a00000
000551555555554444444444445550000000000000055555555555555544444444455555000055500555555555555555554444444445555555555000aaa00000
00555555666555564444444445555500000000000555555556665555555555444455555555555500055555555666655554444444444555550000000000000000
55555556666555564444444445555550000000000555566666666555555544444455555555550000006666666666666666444444444550000000000000000555
55556666666655574444444446555555000000000066666666666777744444444465555555555000000006666666666777444444440000000000000000005555
06666660000005550444444400055555555000000000000000000000004444444000000000005550000000000000000000044444400000000000000000005515
00000000000000555044444000000555555500000000000000000000000444440000000000000000000000000000000000004444000000000000000005555555
00000000000000000000000000000005505500000000000000000000000000000000000000000000000000000000000000000000000000000000000005555555
00000000000000000000000000000005550500000000000000000000000000000000000000000000000000000000000000000000000000000000000000666666
00000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
cccccccc777777777777777700a00000dddddddddddddddddddddddddddddddd00000000ccccccccccccccdddd5dd5d555ddd555cccccccccccccccccccccccc
cccccccc7777777777777777ffffff00dddddddddddddddddddddddddddddddd00000000cccccccccccc5d5555555d5ddddddd5555555555cccccccccccccccc
cccccccc7777771111111177f1ff1f00dddddddd44444444dddddddddddddddd00000000cccccccccddddddddddd55d555ddddddddddddd555cccccccccccccc
cccccccc7777711cccc77117ffffff00dddddddd44444444dddddddddddddddd00000000cccccc55dddddddddddddd55dddddd5555dd55ddd55ccccccccccccc
cccccccc777711ccccccc711fff66660dddddddd44444444dddddddddddddddd00000000ccccdddddddddddddddddddd55555dddddd55555dddd5ccccccccccc
cccccccc77711ccccccccc7106676760dddddddd44444444dddddddddddddddd00000000cccddddddddddddddddddddddddddddddddddddddddddd555ccccccc
cccccccc7771ccccccc11cc166766760dddddddd44444444dddd4444444ddddd00000000cddddddddddddddddddddddddddddddddddddddd555555dddddccccc
cccccccc7711cccccc1171c167667760dddddddd44444444d4444444114441dd00000000dddddddddddddddddddddddddddddddddddddddddddddd555dd5dd55
44444444771ccccccc17771767777660dddddddddddddd444414414111444111ddddddddddddddddddddddddcccccccccccccccc000000000000000000000000
44444444711ccccccc17777766666670dddddddddddd1411111114144444441111111111ddddddddddddddddcccccccccccccccc000000000000000000000000
4444444411cccccccc11777707777770ddddddddd444444444441141114444444444444111ddddddddddddddcccccccccccccccc000000000000000000000000
444444441cccccccccc1177706666660dddddd1144444444444444114444441111441144411dddddddddddddcccccccccccccccc000000000000000000000000
444444441ccccccccccc111100077770dddd44444444444444444444111114444441111144441dddddddddddcccccccccccccccc000000000000000000000000
44444444cccccccccccccc1100000000ddd4444444444444444444444444444444444444444444111dddddddcccccccccccccccc000000000000000000000000
44444444cccccccccccccccc00000000d44444444444444444444444444444444444444411111144444dddddccccdddddddccccc000000000000000000000000
44444444cccccccccccccccc0000000044444444444444444444444444444444444444444444441114414411cddddddd55ddd5cc000000000000000000000000
09999999999999999999000011111111000000001111111111111111111111115555566500000000000000000000000000000000000000000000000000000000
99444994444444444449900011111111000000001111111111116111111111115665555500000000000000000000000000000000000000000000000000000000
94444494444444444444900011111111000000001111111111116111111111115575555600000000000000000000000000000000000000000000000000000000
94444494444444444444900011111111000000001111111111117111111111117565565500000000000000000000000000000000000000000000000000000000
99999999999999999999900011111111000000001111111111177111111111115555557500000000000000000000000000000500000000000000000000000000
00000000000000000000000011111111000000001111161111165111116111115555675500000000000000000000000000055100000000000000000000000000
00000000000000000000000011111111000000001111171111755711156111115577555700000000000000000000000001151151000000000000000000000000
00000000000000000000000011111111000000001111656767557565765711116665555500000000000000000000000015111111000000000000000000000000
99999999999999999999900055555555111111111111756757656566566711111111111111111111000000000000000111111111111000000000000000000000
94444494444444444444900055555555111161111117766756565555655577111161111111111111000000000000015151115111155511000000000000000000
94444494444444444444900055555555111161171166665555555756555665611161111111111111000000000000111111111111111111500000000000000000
94444494444444444444900055555555111166677655557556555555555555757777111111111111000000000015511155511155111151555500000000000000
94444494444444444444900055555555111775555555555555555555665555556655716111111111000055551511115111151111111115511110000000000000
94444494444444444444900055555555116555655556755555555555555566555555677611111111000111111551111111111111111111111115500000000000
99999999999999999999900055555555165555555555555555555555555556655555555777111111051151111111111111111111111111111511155100000000
00000000000000000000000055555555765555555555555555555555555555555555556556576667511111111111111111111111111111111111111100000000
00000000000000000000000000000000a000000000000000000000000000000000000000a000000000000000000000000000000000000000a000000000000000
000000000000000000000000000000aaa0000000000000000000000000000000000000aaa0000000000000000000000000000000000000aaa000000000000000
0000000000000000000000000000aaaaaa0000000000000000000000000000000000aaaaaa0000000000000000000000000000000000aaaaaa00000000000000
00000000000000000000000000aaaaaaaa00000000000000000000000000000000aaaaaaaa00000000000000000000800000000000aaaaaaaa00000000000000
000000000000000000000000aaaaaaaaaaa00000000000000000000988000000aaaaaaaaaaa00000000000000000098000000000aaaaaaaaaaa0000000000000
00000000000000098000000aaaaaaa9aaaa0000000000000000000880000000aaaaaaa9aaaa0000000000000000008000000000aaaaaaa9aaaa0000000000000
0000000000000088980000aaaaaaaa9aaaa000000000000000000080000000aaaaaaaa9aaaa00000000000000000a800000000aaaaaaaa9aaaa0000000000000
0000000000000a90080000aaaaaaaaa9aaa0000000000000000009a0000000aaaaaaaaa9aaa000000000000000009000000000aaaaaaaaa9aaa0000000000000
000000000000080000000aaaaaaaaaa9aa0000000000aa000000080000000aaaaaaaaaa9aa0000000000aaa00000800000000aaaaaaaaaa9aa00000000000000
000a000000000a0000000aaaaaaaaaaaaa00000000000aa000000a0000000aaaaaaaaaaaaa000000000000aaaa00a00000000aaaaaaaaaaaaa00000000000000
000a000000000900000008aaaaaaaaaaa0000000000000aa00000900000008aaaaaaaaaaa0000000000000000a009900000008aaaaaaaaaaa000000000000000
000aa00000000aa000000aaaaaaaaaaaa00000000000000aaa000aa000000aaaaaaaaaaaa0000000000000000aa00aa000000aaaaaaaaaaaa000000000000000
0000aa00000000900000aaaaaaa8aaaa00000000000000000aa000900000aaaaaaa8aaaa000000000000000000aaaa900000aaaaaaa8aaaa0000000000000000
00000aaaaaaa00aa9a9aaaaaaaaaaaa0000000000000aa0000a000aa9a9aaaaaaaaaaaa0000000000000aaa0000aaaaa9a9aaaaaaaaaaaa00000000000000000
00000000000aaaaaaaaaaaaaaaaaa0000000000000000a0000aaaaaaaaaaaaaaaaaaa00000000000000000aaa000aaaaaaaaaaaaaaaaa0000000000000000000
00a00000000999aa9aaaaaaaaaa000000000000000000aa0000999aa9aaaaaaaaaa000000000000000000000aa0099aa9aaaaaaaaaa000000000000000000000
000aaaaaa000999aaaa99aaaaaa0000000000000000000aaa000999aaaa99aaaaaa0000000000000000000000aa0099aaaa99aaaaaa000000000000000000000
0000000aaaaaaaaaa999aaa9aaa00000000000000000000aaaaaaaaaa999aaa9aaa00000000000000000000000aaaaaaa999aaa9aaa000000000000000000000
000000000aaaaaaa99999aa99a9a000000089800000000000aaaaaaa99999aa99a9a00000000888000000000000aaa9aa9999aa99a9a00000000000800000000
000000000000009a990000a999aa000000880a0000000aaa0000009a990000a999aa000000000a9000000aaaaa00009a9a0000a999aa00000000000800000000
0000000000000aa9900000a9099a900000000a000000000a00000aa9900000a9099a9000000000a0000000000aa00aa990a000a9099a9000000000a900000000
000000000aaaaa00a0000aa00099aa0000000a000000000aaaaaaa00a0000aa00099aa0000000a800000000000aaaa0000aaaaa00099aa0000000a8000000000
000aaaaaaa000000aa00aa00000009a0000098000000000000000000aaaaaa00000009a00000980000000000000000000000aa00000009a00000980000000000
00000000000000000aaaa000000000a9a9a88000000000000000000000000000000000a9a9a88000000000000000000000000000000000a9a9a8800000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
04020402000000000801000b0800000003000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3434340000000000000000000000000034003434000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003434343434343434343434003434000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3434343434343434343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000059
3434343434343434343434343434343434000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595a5b
343434343434343434343434343434343400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050595a5b5c5b
34343434343434343434343434343434343400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595a5b54545c64
3434343434343434343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595a545c5c54546467
34343434343434343434343434343434340000000000000000000000506b6c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006b6c00000000000000000000000000000000000000000000000000000000000000595c545b54545c646766
343434343434343434343434343434343400000000006b6c000050595a5b5c5d5d5e5f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595d5a5b5c5d5e5f0000000000595d5e5f0000000000006b6c000000000000000000595a5c5b5454545c64676667
3434343434346b6c343434343434343434000000595a5c5b5d5e5a5b5c5b5c5b545b5c5d5e5f0000000000000000000000000000000000000000000000000000006b6c00000000000000000000000000595a5c5b545454545b5b5d5e5f595a5c54545c5d5d5e5f595a5b5d5e5f0000000000595a545c54546465686566676060
58343450595a5b5c5d5e5f346b6c3434346b595a5b5c5b5b5c545b54545454545c545c5c5b5c5d5e5f595d5d5e5f000000000000006b6c0000000000000000595a5c5c5d5d5e5f6b6c5050000000595a5b545c54545c5657545454545b545657545454546468696a5454545c5b5d5e5f595a5c5c545464656660676766606066
5e5f595a5c545c5c5b5c5b5d5c5b5d5e5a5b5c5b545c5b54545454545b54545454545454545c5c5b5454545c545b5d5e5f0000595a5c5b5d5e5f6c0000595a5b56575454545c5b5c5c5d5e5f595a5c5c54545454646566676768696a6465676668696a6467606666696a5454545c5b5b5c545454646567606060606660606060
5b5c5b5454545454565754545454545c5c545b5454545454545b545c5454546468696a54545454545c54545454545456575d5a5b5c5b54545b5c5b5d5a566465676768696a5454545b5454545c5454545b5464656667666760676667606760676066666066606066676668696a6468696a646865676060666766606060606060
5454545454566465666768696a545c54545454545c54545454545b5454646566676667676868696a646868696a6465676668696a6465666768696a6465666766606766676668696a646566685555696a646567606060606066606066676060606067606660606760606067666760666766676067666067606060606760606660
6465676865676667666767666768696a6468686768696a64696a6a6465666667606766676060666667666760606667606060666660606760606666676060606066606060666766676660606767666766676060606667606760606066606060606060606060606060606060606060606060606060606060606060606060606060
6766676060606060606060606060606760606660606060606060606660606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000007c00000000000000000000000000000000007c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000008b8c8d8e000000000000000000000000008a8b8c8d8e8a8b8d8e00000000000000000000000000000000008a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000008a8b8c73738c8d8e8a8b8d8e000000007c8a8b8c8d8c738d8c8c738d8d8e8a8b8c8d8e00000000007c8a8b8c8c8c8d8e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000587c8b8c73738c73738c73738c738c8d8e8a8b8c8c738c7373738c7373738c76738c73738c8d8d8e8a8b8c8c738c7373738d8c8d8e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007c00008a8b8c75767773737373738c737373738c8d8c738c737373738c7373737389848788737373737373737373738c7373738c73738c738d8d7c00007c8e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8b8c8d8b7373848586878889848889737373737373737373737373737373737373848583788687887373738c73737373737373737373737373738c8c8d8b8d8d8d8e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8c737373848578867883868686788687888973737373737373737375767775848586868383837883878876737373737373737373737373737373767373738c738c8c8d8e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
737384857883838386838378837886788386878889898485888485867886867886837883788383837883788788898485878876737373737384858687888c7373737373738d8e7c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8485868683838383838386838383838383838386867886867883838683838683838383838383838386838383838686837883868788768485868383838687888973738c738c8c8d8d8b8d8e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
83838383838383838383838383838383838386788383838383868383838383838386838383838383838383788383788683838383867883838683838383838687888973737373738c73738c8d8e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
83838383838383838383838383838383838383838383838383838383838383838383838383838383838386838383838383838383838383838378838683838378868789898989737373738c738d730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010300000e5702d5202f570303703237034370363703a3703e370393703737036570325703257031370313702f5702d5302d3702d3702d3702c5702b5502a530295203630038300393003a300373003330033300
0001000015600256202565027650296502c6502f650326503265034640356303663036630366303762036620366203662036620366203662036620356103561034610306102f6102f6102f6102e6102d6102d610
010c00001a613000003e605000003e6153e6051a613000003e605000001a613000003e615000003e605000003e6153e6152f70037700307002f7003e6253e600257002a70027700297003e6252e7003470037700
000200000d7701077015770187701b7701f7702277026770297702d7702e770307703277033770347703477034770347703377032770307702e7702b7702877026770217701e7701b77018770177701477000000
00040000000003c470364003847035470334703847034470304702d4003c470394703c470374703947035470384703347037470354003547037470334703747032400334703647033470354703e4702d40031400
010c0000261252672526101261012610126101261252612526125261252610526101261012610126101261012612526125261251a1251a7251a125261252612526125261251a7251a1251a7251a1251a7251a125
010a0000395553b555305053e50534505355053750539505295052c5052e5053350538505275052550524505295052c5052d5052d5052d5052e5052f5052f505305053050530505305053050530505305052f505
010c0000261252672526701267012670126701267252672526725267252670526701267012670126701267012972529725297251a7051a7051a7052d7252d7252d7252d7251d7051d1051d7051d1053272232722
010c002000570005750250009702097020970200570005750250000702007020450004570045750170201701025700257502500340053b0050000505572055723c00538005000050000509572095720000500005
012a00081a611016011a611016011a611036011a61100601006010060100601006010060100601006010060100601006010060100601006010060100601006010060100601006010060100601006010060100601
010e00001a5221a5021a5221a5221c5221c5221c5221a5021a5221a5021a5021c5221c5021c5261c5221a5021a5221a5021a5221a5221c5221c5221c522265021f52221522215021f5221c5021e5221c52219502
013200001073410722107251072510724107451072510725107341072210725107251072410745107251072510734107221072510725107241074510725107251073410722107251072510724107451072510725
013200001c0151e0152001521015230150000028005280152701525005250150000023015000000000028015270151e005250151b00527015280152a015200052c01500000210150000020015000001e00500000
012a00101e0551e0051c0551c0051805518005180051c0551e05523055210551c0551e055000051b0050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
012a00000c0640c0410c0410c0410c0420c0410c0420c0410c0320c0320c0320c0320c0220c0220c0120c0120b0640b0410b0410b0410b0420b0410b0420b0410b0320b0320b0320b0320b0220b0220b0120b012
012a00001710217112101121711217102171121011217112171021711210112171121710217112101121711217102171121011217112171021711210112171121710217112101121711217102171121011217112
012a00001e055000051c055000051805518005000051c0551e05523055210551c0551e0550000500005000051e055000051c055000051805500005000051c0551e0552305521055000051f0051d0051f0551e055
012a00001c055170551305512055100450b0450703506035040350000000000000000000000000000000000000000000000000000000000000000000000000001303413032130321303213032130321303213032
012a00001c00500000000000000000000000000000000000180241802218022180221c0341c0321c0321c0321e0341e0321e0321e0321a0241a0221a0221a0221c0341c0211c0211c0211c0211c0211c0211c021
012a00001c0051e0051f005000002300521005210051a0051c0051a0051c0051c0051c0051c0051c0051e0051c0051e0051f0052400523005000001c0451e0551f065000002306521005210651a005210051a065
0131000815045190351c035200351e03521035200351c0251500515005150052300524005240052400524005240052400524005240052300523005230051d0051d0051d0051d0051d0051c0051c0051c0051c005
013100002554425540255402554225532255322553223534255542555225552255522555225542255422354220574205721e5741e57223574235721e5741e5721e5741e5721c5741c57221574205741c57419554
01310000175441754017540175421753217532175321c5341955419552195521954219542195321953219532175341753217532175321754217542175421c55419544195421e5441e5421c5541c5522055420552
0131000015025190351c035200351e03521035200351c03515035190351c035200351e03521035200351c03515035190351c035200351e03521035200351c03515035190351c035200351e035210352004523055
01310000180451c0451f045230452104524045230451f045180451c0451f045230452104524045230451f04515035190351c035200351e03521035200351c03521035190351c005200351c03521005190451c005
013100001c5441c5521c5521c5521c5521c5521c5521f5441c5541c5621c5621c5621c5621c5621c5621a55219564195621957219572195621956219552195521954219532195221951200000000000000000000
01310008180351c0351f035230352103524035230351f035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
013100001c5441c5521c5521c5521c5521c5521c5521f5441c5441c5521c5521c5521c5521c5521c5521f54421564215621f5641f56224564245621f5641f56221574215721f5741f572235641f564215541d544
012a00001c0651a0051c0051c0051c0051c0051c0451e0551f065000002306521005210651a00521005260652806526005280051c0051c0051c0051c0451e0551f065000002306521005210651a0052100526065
012a00001003410032100321003210032100321003210032130341303213032130321303213032130321303210034100321003210032170321703215032150321303413032130321303213032130321303213032
012a00001300413001130011300113002130011300213001000000000000000000000000000000000000000000000000000000000000000000000000000000001703417021170211702117021170211702117021
002a000013034130211302113021130211302113021130211c0341c0211c0211c0211c0211c0211c0211c02113034130211302113021130211302113021130211c0341c0211c0211c0211c0211c0211c0211c021
002a00001703417021170211702117021170211702117021170341702117021170211702117021170211702117034170211702117021170211702117021170211703417021170211702117021170211702117021
002a0000130341303213032130321303213032130321303215034150321503215032150321503215032150320e0340e0320e0320e0320e0320e0320e0320e0320e0320e0320e0320e0320e0220e0220e0120e012
002a00001a0341a0211a0211a0211a0211a0211a0211a021180341802118021180211802118021180211802113034130211302113021130211302113021130211301113011130111301113001130011300113001
002a00002306523005230052300521065210051f0651f0051e0651e0051c005000001c065000001a065000001706500000000000000015065000001a065000001706500000000000000015055000001304500000
002a000017034170211702117021170211702117021170211c0341c0211c0211c0211c0211c0211c0211c02117034170211702117021170211702117021170211701117011170011700117001171021010217102
011000081c65500605006050060504655006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000100070534705347453474500705007053474500705007050070534745347053474534745007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
012000001c435004052040520435234352343520435204051c4350040520405204352343523435204350c405154350040520405194351c4351c43519435204051743500405004051b4351e435204351e43500405
01200000232552320523255202052125520255002051e2551c25520255202552025500205202552125523255252552725528255272552525523255202551e2551c25520255202552025500205002050020500205
011600001c4451c4550b4051c455104051e455204551b405214651e4551c4051e4551e4551040520455214552346523455234052345500405214552045500405214551e445004051e4451e445004050040500405
011600002f5252f5252f5252c5052c5252c5252d5251e5052a5252a5252a52525505255252552527525285052a5252a5252a525275052752527525275252a5252d5252d5253152519502195022a5253652519502
011600081c633080030b0030f0033463514003170031b003041030410304103041030410304103041030410304103041030410304103041030410304103041030410304103041030410304103041030410304103
010c0000127561c7261e736207461b7061b706107061c706177060f7061270617706127060f706127061770610706047060470604706047060470604706047060470604706047060470604706047060470604706
010c000002570025751a500005001a5001a50002570025751a5001a50000500005001a50005500055000050005570055751a500005001a5001a50005570055751a5001a5000050000500005001a5000050000500
010c00000a5700a5751a500005001a5001a5000a5700a5751a5000050000500005000050000500005000050000570005751a500005001a5001a50000570005750050000500005000050000500005000050000500
010c00001a623000003e605000003e6253e6051a623000003e605000001a623000003e625000003e605000001a623000003e605000003e6253e6051a623000003e605000001a623000003e625000003e60500000
010c000026735261352673526135297352913529135297352d7352d1352d1352d7353513535735351353573526735267352613526135297352913529735291352d7352d1352d7352d13535735351353573535735
010c0000027410274202742027420274202742027420274202741027420274202742027420274202742027420e7410e7420e7420e7420e7420e7420e7420e7420e7410e7420e7420e7420e7420e7420e7420e742
010c00001a7411a7421a7421a7421a7421a7421a7421a7421a7411a7421a7421a7421a7421a7421a7421a742267412674126741267412674126742267422674226741267412674126741297412d7413274132741
010c00003274232742327423274232741327423274232742327413274232742327423274132742327423274230741307423074230742307423074230742307423174131742317423174231742317423174231742
010c00003274232745327023270232702327023274232745297022970535702357053570235705357023570529702297053574235745357423574535742357453574235742357450000037742377450000000000
010c0000397423974239742397423974239742397423974239742397423974239742397423974239742397413c7413c7423c7423c7423c7413c7423c7423c7423474134742347423474234741347423474234742
010c00003274232745327023270232702327023274232745000000000000000000000000000000000002970500000297053074230745307423074530742307453074230742307030000034742347450000000000
010c00002d7352d1352d7352d135317353113531135317353473534135341353473537135377353713537735287352813528735281352b7352b1352b1352b7352f7352f1352f1352f73534135347353413534735
010c000005570055750250009702097020970205570055752b7052b1052b1052b7052b7052b1052b1052b70502570025750250009702097020970202570025752b7052b1052b1052b7052b7052b1052b1052b705
010c00000057000575025000970209702097020057000575025000070200702045000457004575017020170102570025750250009702097021470002570025753570235702357023570234702347023470234702
010c00003414532745301452d74532145307452d1452b745301452d7452b145297452d1452b7452914528745261452670526702267020e7020e7051a7021a7050000000000000000000000000000000000000000
010c000032755327422d7522d7452d7022d7022d7022d7022d7052d7022d7022d7022d7022d7022d7022d7021a1451a7451a1451a7451d1451d7451d1451d7452114521745211452174526145267452614526745
010c000026145267452614526745291452974529145297452d1452d7452d1452d745321453274532145327453514534745321453074532145307452d1452b7452d1452b745291452874529145287452614524745
010c00001d1451d7451d1451d7452114521745211452174524145247452414524745291452974529145297452d5452b5452954528545295452854526545245452654528545265452454526545285452654524545
010c00001a1451a7451a1451a745181451874518145187451a1451a7451a1451a7451d1451d7451d1451c7453e1453e60502605000000000002605091420914202605026050e6053e60513142131423e6053e605
010c00003974139742377423774235741357423474234742357413574234742347423274132742307423074232742327013470134701357013570130742307423e7023e7023e7023e70231742317423e7023e701
__music__
01 14154444
00 14154344
00 17164344
00 1a1b4344
02 18194044
01 0d0e0f44
00 100e0f44
00 1112131e
00 1d1f1c20
02 21222324
03 28272526
03 292a2b44
01 2f2d3031
00 2f2e3032
01 2f2d3033
00 2f2e3034
00 2f2d3035
00 2f2e3036
00 2f383a3b
00 2f393c3d
00 2f383a3b
00 2f393c3d
00 2f380507
02 02083e3f
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

