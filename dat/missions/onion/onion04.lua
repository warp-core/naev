--[[
<?xml version='1.0' encoding='utf8'?>
<mission name="Onion Society 04">
 <unique />
 <priority>3</priority>
 <chance>50</chance>
 <location>Bar</location>
 <done>Onion Society 03</done>
 <cond>
   local c = spob.cur()
   local f = c:faction()
   if not f or not f:tags("generic") then
      return false
   end
   return true
 </cond>
 <notes>
  <campaign>Onion Society</campaign>
 </notes>
</mission>
--]]
--[[
   Onion04

   Player has to take a one-time pad from a convoy, and then swap the cargo
   with another convoy on the way there. Afterwards, they have to swap the
   cargo with another another ship, and finally infiltrate the final place
   before getting away.
--]]
local fmt = require "format"
local vn = require "vn"
local onion = require "common.onion"
local love_shaders = require "love_shaders"
local lmisn = require "lmisn"
local fleet = require "fleet"
local pltai = require "pilotai"
local der = require 'common.derelict'
--local lg = require "love.graphics"

-- Action happens on the jump from Action happens Overture to Dohriabi on the Overture side
local ambushsys = system.get("Overture")
local swapspb, swapsys = spob.getS("Fuzka")
local targetspb, targetsys = spob.getS("Nexus Shipyards HQ")
local jmpsys = system.get("Dohriabi")
local jmp = jump.get( ambushsys, jmpsys )
local runjmp = jump.get( ambushsys, system.get("Nartur") )

--local money_reward = onion.rewards.misn04

local title = _("Onion Bank Heist")

--[[
   Mission States
   0: mission accepted
   1: took one-time pad
   2: (optional) landed once before swapspb
   3: ship cargo swapped at swapspb
   4: mini-game done
   5: escaped
--]]
mem.state = 0

-- Create the mission
function create()
   misn.finish(false)
   -- Claim the ambush and escape stuff
   if not misn.claim{ ambushsys, targetsys } then
      return misn.finish(false)
   end

   local prt = love_shaders.shaderimage2canvas( love_shaders.hologram(), onion.img_l337b01() )

   misn.setNPC( _("l337_b01"), prt.t.tex, _([[You seem to have an incoming connection from the Onion Society.]]) )
   misn.setReward(_("???") )
   misn.setTitle( title )
   misn.setDesc(_([[Help l337_b01 and Trixie do a bank heist.]]))
end

function accept ()
   local accepted = false

   vn.clear()
   vn.scene()
   local l337 = vn.newCharacter( onion.vn_l337b01{pos="left"} )
   local trixie = vn.newCharacter( onion.vn_trixie{pos="right"} )
   vn.music( onion.loops.hacker )
   vn.transition("electric")
   vn.na(_([[You answer the incoming connection and some familiar holograms appear on-screen.]]))
   l337(fmt.f(_([["Heyo, how's it going {player}?"]]),
      {player=player.name()}))
   trixie(_([["Yo."]]))
   vn.menu{
      {_([["Yo."]]), "01_cont"},
      {_([["Heyo."]]), "01_cont"},
      {_([["Hello."]]), "01_cont"},
   }

   vn.label("01_cont")
   l337(_([["Was poking at the Nexus Shipyards security with Trixie, and it seems like we've got a path into the mainframe, although it's a bit convoluted."]]))
   trixie(fmt.f(_([["It seems like there's an important convoy coming from {startspb} to {targetspb} with some of the new encryption protocols and one-time pads. However, we can't really directly mess with them, or they'll redo the entire encryption, and it's moot."]]),
      {startspb=spob.get("Emperor's Wrath"), targetspb=targetspb}))
   l337(fmt.f(_([[l337_b01 butts in, "but if we manage to swap the one-time pad with another, we can get access there. We've found another suitable convoy that will be going through the {sys} system."]]),
      {sys=ambushsys}))
   trixie(fmt.f(_([[Trixie counter-butts in, "Yes, so we need you to raid the convoy in {sys} system, and then deliver that to {swapspb} in the {swapsys} system, and we can handle the rest!"]]),
      {sys=ambushsys, swapspb=swapspb, swapsys=swapsys}))
   vn.menu{
      {_([["Count on me!"]]), "02_yes"},
      {_([[Maybe later.]]), "02_later"},
   }

   vn.label("92_later")
   vn.na(_([[You decline the work for now, and the holograms fade away.]]))
   vn.done("electric")

   vn.label("02_yes")
   vn.func( function () accepted = true end )
   l337(_([["Great! Trixie and I will be using your ship as a beacon, and should be able to help you as bandwidth allows."]]))
   trixie(_([["The convoy will be jumping from the {jmpsys} system to the {ambushsys} system. It's our best bet due to the high bandwidth and few ships to capture the cargo."]]))
   l337(fmt.f(_([["No need to fret, {player} is an excellent pilot and this will be no challenge for the {shipname}!"]]),
      {player=player.name(), shipname=player.pilot():name()}))

   vn.done("electric")
   vn.run()

   if not accepted then return end

   misn.accept()
   misn.markerAdd( ambushsys )
   mem.state = 0
   hook.land("land")
   hook.enter("enter")
   misn.osdCreate( title, {
      fmt.f(_([[Steal one-time pads from the convoy in the {sys} system]]),
         {sys=ambushsys}),
      fmt.f(_([[Land on {spb} ({sys} system)]]),
         {spb=swapspb, sys=swapsys}),
   } )
end

function land ()
   local cspb = spob.cur()
   if mem.state==1 or mem.state==2 and cspb==swapspb then
      -- TODO use an NPC
      -- Cargo swap cutscene
      vn.clear()
      vn.scene()
      local l337 = vn.newCharacter( onion.vn_l337b01{pos="left"} )
      local trixie = vn.newCharacter( onion.vn_trixie{pos="right"} )
      vn.music( onion.loops.hacker )
      vn.transition("electric")
      l337()
      trixie()
      vn.done("electric")
      vn.run()

      misn.osdCreate( title, {
         fmt.f(_([[Break into {spb} ({sys} system)]]),
            {spb=targetspb, sys=targetsys}),
      } )
      mem.state = 3
   elseif mem.state==1 then
      -- Small extra cutscene
      vn.clear()
      vn.scene()
      local l337 = vn.newCharacter( onion.vn_l337b01{pos="left"} )
      local trixie = vn.newCharacter( onion.vn_trixie{pos="right"} )
      vn.music( onion.loops.hacker )
      vn.transition("electric")
      l337()
      trixie()
      vn.done("electric")
      vn.run()
      -- Advance internal state
      mem.state = 2

   elseif mem.state==3 and cspb==targetspb then
      -- TODO probably use an NPC
      mem.state = 4
   end
end

function enter ()
   hook.timerClear()
   if system.cur()==ambushsys and mem.state==0 then
      hook.timer( 7, "prepare" )
   end
end

local convoyspawn
local distlim = 5e3
local mrk
function prepare ()
   -- Skip talk if jumping in from jmpsys
   if player.pos():dist( jmp:pos() ) < distlim then
      convoyspawn()
      return
   end
   player.msg(_("l337_b01: Head towards the jump. They should be here soon!"), true)
   mrk = system.markerAdd( jmp:pos() )
   hook.timer( 1, "wait" )
end

function wait ()
   if player.pos():dist( jmp:pos() ) < distlim then
      convoyspawn()
      return
   end
   hook.timer( 1, "wait" )
end

local enemies, spam
function convoyspawn ()
   if mrk then
      system.markerRm( mrk )
      mrk = nil
   end
   player.msg(_("trixie: Oh boy, that's a lot of ships. Get close and we'll hack!"), true )

   -- Clear up
   pltai.clear()

   local ships = {
      "Gawain", -- has the cargo
      "Pacifier",
      "Pacifier",
      "Pacifier",
      "Admonisher",
      "Admonisher",
      "Admonisher",
      "Admonisher",
      "Admonisher",
      "Shark",
      "Shark",
      "Shark",
      "Shark",
      "Shark",
      "Shark",
   }
   local fct = faction.dynAdd( "Dummy", "_onion_nexus", _("Nexus IT"), { ai="baddie" } )
   local names = {}
   for k,s in ipairs(ships) do
      names[k] = fmt.f(_("Nexus {ship}"), {ship=ship.name(s)})
   end
   enemies = fleet.add( 1, ships, fct, jmp, names )

   local minspeed = math.huge
   for k,p in ipairs(enemies) do
      minspeed = math.min( p:stats().speed_max * 0.95, minspeed )
   end

   local l = enemies[1]
   hook.pilot( l, "board", "board" )
   hook.pilot( l, "death", "death" )
   hook.pilot( l, "land", "gawain_lost" )
   hook.pilot( l, "jump", "gawain_lost" )
   l:setHilight(true)
   l:setVisplayer(true)
   l:control(true)
   l:jump(runjmp)
   l:setSpeedLimit( minspeed )
   hook.timer( 8, "heartbeat" )
   spam = 0
end

function gawain_lost ()
   lmisn.fail(_([[You lost track of the target!!!]]))
end

function heartbeat ()
   local l = enemies[1]
   local _a, _s, _ss, dis = l:health()
   if dis then
      -- Player already disabled, nothing to do
      return
   end
   if l:dist( player.pos() ) < 1500 then
      local fct = faction.dynAdd( "Dummy", "_onion_nexus_hacked", _("Nexus IT (Hacked)"), { ai="baddie" } )
      l:disable()
      local dohack = { 3, 6, 8, 11, 14 } -- IDs of ships to hack
      for k,p in ipairs(enemies) do
         if p:exists() then
            local hacked = inlist( dohack, k )
            if hacked then
               p:effectAdd("Onionized")
               p:setFaction( fct )
               p:setFriendly(true)
            else
               p:setHostile(true)
            end
         end
      end
      player.msg(_("l337_b01: Script deployed! Time to cry!"), true )
      return
   end
   spam = spam-1
   if spam < 0 then
      player.msg(fmt.f(_("trixie: See the {p}? Get closer!"),{p=l}), true )
   end
   hook.timer( 1, "heartbeat" )
end

function board( p )
   vn.clear()
   vn.scene()
   vn.transition()
   vn.sfx( der.sfx.board )
   vn.na(fmt.f(_([[Your ship approaches the {shp}, and you rip off the cargo pod and make your way.]]),
      {shp=p}))
   vn.sfx( der.sfx.unboard )
   vn.run()

   -- Give the player the cargo
   local c = commodity.new( N_("Nexus Cargo Pod"), N_("Cargo taken from Nexus Shipyards.") )
   mem.cargo = misn.cargoAdd( c, 0 )

   mem.state = 1
   misn.osdActive(2)
   misn.markerRm()
   misn.markerAdd( swapspb )

   hook.timer( 5, "postboard" )
end

function postboard ()
   player.msg(fmt.f(_("l337_b01: Got the goods, on to {spb}!"),{spb=swapspb}), true )
end

function death ()
   lmisn.fail(_([[You were supposed to capture the cargo, not destroy the ship!]]))
end
