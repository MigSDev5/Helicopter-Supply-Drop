/*
	Author: tDavison
	Inspiration: blckeagls / A3AEI / VEMF / IgiLoad
	License: Attribution-NonCommercial-ShareAlike 4.0 International
*/

// north, south, east, west starting locations for supply helicopter
// these distances are all oceanic spawns
_posArray = [[15971.3,25950.5,200],[14727.5,3934.5,200],[26869.5,15454.5,200],[1306.16,14832.8,200]];

//how high up (meters) should parachute open (default: 150)
//I'd recommend keeping minimum around 200 as heli flies in at that height
_chuteMinDistanceToOpen = 160;

//random supply helicopter spawn
_heliSpawnPosition = _posArray call bis_fnc_selectrandom;  

//these variables determine a safe location for the supply crate drops
//map center is based on ALTIS with halved values
_mapCenter = [7720,7671,0];
_coords = [_mapCenter,500,14000,30,0,10,0] call BIS_fnc_findSafePos;

//create helicopter and spawn it
_supplyHeli = createVehicle ["I_Heli_Transport_02_F", _heliSpawnPosition, [], 90, "FLY"];
_supplyHeli flyInHeight 200;
_supplyHeli setVehicleLock "LOCKED";
clearWeaponCargoGlobal _supplyHeli;
clearMagazineCargoGlobal _supplyHeli;

//keep heli around until we delete it
_supplyHeli call EPOCH_server_vehicleInit;
_supplyHeli call EPOCH_server_setVToken;

//add crew to supply helicopter
createVehicleCrew (_supplyHeli);

//set waypoint for heli - this is where it goes
_wpPosition = _coords;

/* FOR TESTING ONLY - shows approx 600m radius where crate will get dropped */
//_markerTmp = createMarker ["tempMarker", _wpPosition ];
//_markerTmp setMarkerSize [600,600];
//_markerTmp setMarkerBrush "DiagGrid";
//_markerTmp setMarkerShape "ELLIPSE";
//_markerTmp setMarkerColor "ColorYellow";
/* END TEST */

//tell heli to move to position to drop crate
_supplyHeli move _wpPosition;

//Announce a drop is inbound to all players
["A supply helicopter has been spotted!"] execVM "\SDROP\scripts\SDROP_Alert.sqf";

//Waits until heli gets near the position to drop crate
waitUntil {_supplyHeli distance _wpPosition < 400 };

//create the parachute and crate
_crate = createVehicle ["IG_supplyCrate_F", [0,0,0], [], 0, "CAN_COLLIDE"];
_crate setPos [position _supplyHeli select 0, position _supplyHeli select 1, (position _supplyHeli select 2) - 10];

//open parachute when crate reaches minimum distance to open
//this helps prevent too much drift when falling
//however crate can still fall outside the LZ
while {(getPosATL _crate) select 2 > _chuteMinDistanceToOpen} do
{
	sleep 0.2;
};

_chute = createVehicle ["I_Parachute_02_F", position _crate, [], 0, "CAN_COLLIDE"];
_chute call EPOCH_server_vehicleInit;
_chute call EPOCH_server_setVToken;
_crate attachTo [_chute, [0, 0, -1.3]];

//FILL crate with LOOT
_crateTypeArr = ["food","supplies","weapons","random"];
_crateType = _crateTypeArr call bis_fnc_selectrandom;

//Randomize the crate type and fill it
//same crate every time is boring yo!
switch (_crateType) do {
    case "food": {
		[_crate] call SDROPLoadLootFood;
	};
    case "supplies": {
		[_crate] call SDROPLoadLootSupplies;
	};
    case "weapons": {
		[_crate] call SDROPLoadLootWeapons;
	};
	case "random": {
		[_crate] call SDROPLoadLootRandom;
	};
    default {
		[_crate] call SDROPLoadLootSupplies;
	};
};

//return helicopter to spawn and clean it up
_supplyHeli move _heliSpawnPosition;
[_supplyHeli,_heliSpawnPosition] execVM "\SDROP\scripts\SDROP_AI_CleanUp.sqf";

//detach chute when crate is near the ground
waitUntil {getPosATL _crate select 2 < 1 || isNull _chute};
detach _crate;
//_crate setPos [position _crate select 0, position _crate select 1, 0];

//see if crate is in the drink
_crateIsInWater = surfaceIsWater position _crate;

if (!_crateIsInWater) then {
	
	//create marker at supply crate's landing zone (NOTE: only an approximation of where crate will be, and crate could be slightly outside the LZ)
	_marker = createMarker ["SupplyDropMarker", _wpPosition ];
	_marker setMarkerSize [500,500];
	_marker setMarkerBrush "Horizontal";
	_marker setMarkerShape "ELLIPSE";
	_marker setMarkerColor "ColorCIV";
	
	//If you decide to use the marker below, comment out marker above
	//This marker spawns on the crate - giving away the crate's exact position
	//_marker = createMarker ["SupplyDropMarker", getPos _crate ];
	//_marker setMarkerType "mil_objective";
	//_marker setMarkerColor "ColorYellow";

	//pop smoke shell at crate
	_smoke = createVehicle ["SmokeShellPurple", [position _crate select 0, (position _crate select 1) + 1, position _crate select 2], [], 0, "NONE"];

	//Waits until player gets near the _crate to end mission unless crate in water, then continue as it can't be looted anyway
	//announce to players the eagle has landed
	["A supply crate has been delivered! Check your map for the location!"] execVM "\SDROP\scripts\SDROP_Alert.sqf";
	waitUntil{{isPlayer _x && _x distance _crate < 10  } count playableunits > 0};
	
	//delete marker
	deleteMarker "SupplyDropMarker";
	
	//Re-Start supply drop mission
	sleep SDROPMissionTimer;
	[] execVM "\SDROP\missions\SDROP_SupplyDrop.sqf";
	
} else {
	
	//since crate was dropped in water, re-start mission, do some cleanup
	deleteVehicle _crate;
	
	sleep SDROPMissionTimer;
	[] execVM "\SDROP\missions\SDROP_SupplyDrop.sqf";
};