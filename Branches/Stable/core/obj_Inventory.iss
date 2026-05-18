/*
  Provides proxy representation of EVEWindow[Inventory]... child windows via fallthru to the ISXEVE object
  -- CyberTech

		obj_EVEWindow_Proxy inherits all members and methods of the 'eveinvchildwindow' datatype
		Inherited members:

			Capacity
			UsedCapacity
			LocationFlag
			LocationFlagID
			IsInRange
			ItemID
			HasCapacity
			Name

		Inherited methods:
			MakeActive
			OpenAsNewWindow

		Note - You can't access the fallthroughobject members/methods via This; you must use the external name of this object.

*/

objectdef obj_EVEWindow_Proxy
{
	; Prefix variables here with Inv so they have lower chance to overload eveinvchildwindow members
	variable string InvName = ""
	variable int64 InvID = -1
	variable string InvLocation = ""
	variable string EVEWindowParams = ""
	variable index:item Items
	variable int LastMakeActiveAt = 0
	variable int MakeActiveSettleMS = 2500

	method Initialize()
	{

	}

	method SetFallThroughParams()
	{
		EVEWindowParams:Set[""]

		if ${This.InvID} != -1
		{
			EVEWindowParams:Concat["${This.InvID}"]
		}

		if ${This.InvName.NotNULLOrEmpty}
		{
			if ${EVEWindowParams.NotNULLOrEmpty}
			{
				EVEWindowParams:Concat["\,"]
			}
			EVEWindowParams:Concat["${This.InvName}"]
		}

		if ${This.InvLocation.NotNULLOrEmpty}
		{
			if ${EVEWindowParams.NotNULLOrEmpty}
			{
				EVEWindowParams:Concat["\,"]
			}
			EVEWindowParams:Concat["${This.InvLocation}"]
		}
	}

	member:string GetFallthroughObject()
	{
		return "EVEWindow[Inventory].ChildWindow[${EVEWindowParams}]"
	}

	member:float Capacity()
	{
		if ${This.LastMakeActiveAt} > 0 && ${Script.RunningTime} < ${Math.Calc[${This.LastMakeActiveAt} + ${This.MakeActiveSettleMS}]}
		{
			return -1
		}

		if ${Inventory.IsSettling}
		{
			return -1
		}

		return ${${This.GetFallthroughObject}.Capacity}
	}

	member:float UsedCapacity()
	{
		if ${This.LastMakeActiveAt} > 0 && ${Script.RunningTime} < ${Math.Calc[${This.LastMakeActiveAt} + ${This.MakeActiveSettleMS}]}
		{
			return -1
		}

		if ${Inventory.IsSettling}
		{
			return -1
		}

		return ${${This.GetFallthroughObject}.UsedCapacity}
	}

/*
  ~ ChildWindow[ID#]                     :: the first child with the given ID#
  ~ ChildWindow[ID#,"NAME"]              :: the child with the given ID# and the given "NAME" (PREFERRED)
  ~ ChildWindow[ID#,"NAME","LOCATION"]   :: the child with the given ID# and "NAME", at the given "LOCATION"

	NOTE: The name-only patterns (ChildWindow["NAME"] and ChildWindow["NAME","LOCATION"]) are
	DEPRECATED in ISXEVE and will cause console spam. Always include an ID#.

	If ID is not specified, but Name is, MyShip.ID is assumed
	Note that some window types REQUIRE an ID. These will cause an error message to be printed instead of defaulting to MyShip.ID
*/
	method SetLocation(string _Name, int64 _ID=-1, string _Location="")
	{
		This.InvID:Set[${_ID}]
		This.InvName:Set[${_Name}]
		This.InvLocation:Set[${_Location}]
		This:SetFallThroughParams[]
	}

	function Activate(int64 _ID=-1, string _Location="")
	{
		if ${_Location.NotNULLOrEmpty}
		{
			This.InvLocation:Set[${_Location}]
		}

		if ${_ID} <= 0 && ${This.InvID} <= 0
		{
			if ${Inventory.IDRequired.Contains[${This.InvName}]}
			{
				Logger:Log["Inventory.${This.ObjectName}: Station or Entity ID Required for this container type", LOG_ERROR]
				return FALSE
			}
			if ${This.InvName.Length} == 0
			{
				Logger:Log["Inventory.${This.ObjectName}: Neither Name nor ID were specified", LOG_ERROR]
				return FALSE
			}

			This.InvID:Set[${MyShip.ID}]
		}
		elseif ${_ID} != -1
		{
			This.InvID:Set[${_ID}]
		}

		if ${This.InvID} == -1
		{
			Logger:Log["Inventory.${This.ObjectName}: Error: InvID still -1", LOG_ERROR]
			return FALSE
		}

		if ${This.InvName.Equal[StationItems]}
		{
			; Check if we're in a structure by checking if StructureItemHangar window exists
			if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${Me.StationID}, StructureItemHangar](exists)}
			{
				Logger:Log["Inventory.${This.ObjectName}: Structure detected, switching InvName", LOG_DEBUG]
				This.InvName:Set[StructureItemHangar]
			}
		}
		elseif ${This.InvName.Equal[StructureItemHangar]}
		{
			; Check for if we visited a structure and are now at a station, so we have to use original
			if ${Me.InStation} && !${EVEWindow[Inventory].ChildWindow[${Me.StationID}, StructureItemHangar](exists)}
			{
				Logger:Log["Inventory.${This.ObjectName}: Station detected, switching InvName", LOG_DEBUG]
				This.InvName:Set[StationItems]
			}
		}
		elseif ${This.InvName.Equal[StationShips]}
		{
			; Check if we're in a structure by checking if StructureShipHangar window exists
			if ${Me.InStation} && ${EVEWindow[Inventory].ChildWindow[${Me.StationID}, StructureShipHangar](exists)}
			{
				Logger:Log["Inventory.${This.ObjectName}: Structure detected, switching InvName", LOG_DEBUG]
				This.InvName:Set[StructureShipHangar]
			}
		}
		elseif ${This.InvName.Equal[StructureShipHangar]}
		{
			; Check for if we visited a structure and are now at a station, so we have to use original
			if ${Me.InStation} && !${EVEWindow[Inventory].ChildWindow[${Me.StationID}, StructureShipHangar](exists)}
			{
				Logger:Log["Inventory.${This.ObjectName}: Station detected, switching InvName", LOG_DEBUG]
				This.InvName:Set[StationShips]
			}
		}

		This:SetFallThroughParams[]

		call Inventory.Open

		variable int tries
		while !${${This.GetFallthroughObject}(exists)} && ${tries} < 5
		{
			tries:Inc
			wait 20
		}
		if (!${${This.GetFallthroughObject}(exists)})
		{
			Logger:Log["Inventory.${This.ObjectName}: Error: ${This.GetFallthroughObject} doesn't exist", LOG_ERROR]
			return FALSE
		}

		if ${Inventory.${This.ObjectName}.IsActive}
		{
			if ${This.LastMakeActiveAt} > 0 && ${Script.RunningTime} < ${Math.Calc[${This.LastMakeActiveAt} + ${This.MakeActiveSettleMS}]}
			{
				wait 25
			}
			return TRUE
		}
		Logger:Log["\arInventory.${This.ObjectName}: Attempting ${This.GetFallthroughObject}", LOG_STANDARD]
		echo "EVEBOT_INV_DIAG MakeActive before object=${This.ObjectName} target=${This.GetFallthroughObject} running=${Script.RunningTime}"

		Inventory.${This.ObjectName}:MakeActive
		LastMakeActiveAt:Set[${Script.RunningTime}]
		echo "EVEBOT_INV_DIAG MakeActive after object=${This.ObjectName} last=${This.LastMakeActiveAt} running=${Script.RunningTime}"
		; Wait after MakeActive before touching capacity or StackAll; ISXEVE rejects early inventory access.
		wait 25
		Inventory.Current:SetReference[This]
		echo "EVEBOT_INV_DIAG MakeActive current object=${This.ObjectName} trusted=TRUE age=${Math.Calc[${Script.RunningTime} - ${This.LastMakeActiveAt}]} running=${Script.RunningTime}"
		return TRUE
	}

	; Check that the ID/Name/Location match the current ActiveChild of the Inventory window
	member:bool IsActive()
	{
		if ${This.InvID} != ${EVEWindow[Inventory].ActiveChild.ItemID}
		{
			;Logger:Log["\arInventory.${This.ObjectName}.IsActive: ID: ${This.InvID} != ${EVEWindow[Inventory].ActiveChild.ItemID}", LOG_DEBUG]
			return FALSE
		}

		if ${This.InvName.NotNULLOrEmpty} && ${This.InvName.NotEqual[${EVEWindow[Inventory].ActiveChild.Name}]}
		{
			;Logger:Log["\arInventory.${This.ObjectName}.IsActive: Name: ${This.InvName} ${EVEWindow[Inventory].ActiveChild.Name}", LOG_DEBUG]
			return FALSE
		}

		; TODO -- also check location when we're using it
		;if ${This.InvLocation.NotNULLOrEmpty} &&

		return TRUE
	}

	member:bool IsCurrent()
	{
		variable weakref MyThis = This

		if !${EVEWindow[Inventory](exists)}
		{
			return FALSE
		}

		if ${This.InvName.NotNULLOrEmpty} && ${This.InvID} <= 0
		{
			return FALSE
		}

		; Check that the fallthruobject ItemId/Name match what we're expectivng
		if ${MyThis.ItemID} == ${This.InvID} && ${MyThis.Name.Equal[${This.InvName}]}
		{
			return TRUE
		}
		return FALSE
	}

	/* Can be called with no params, 1, or 2.
		GetItems[]                  - This.Items will be populated
		GetItems[NULL]              - This.Items will be populated
		GetItems[<index:items var>] - Passed var will be populated
	  GetItems[NULL, "CategoryID == CATEGORYID_CHARGE"]              - This.Item will be populated and filtered by the given query
		GetItems[<index:items var>, "CategoryID == CATEGORYID_CHARGE"] - Passed var will be populated and filtered by the given query
	*/
	method GetItems(weakref ItemIndex, string QueryFilter)
	{
		variable weakref indexref

		if ${ItemIndex.Reference(exists)}
		{
			indexref:SetReference[ItemIndex]
		}
		else
		{
			indexref:SetReference[This.Items]
		}

		${This.GetFallthroughObject}:GetItems[indexref]
		if ${QueryFilter.NotNULLOrEmpty}
		{
			; TODO - replace this with the querycache
			variable uint qid
			qid:Set[${LavishScript.CreateQuery[${QueryFilter}]}]
			indexref:RemoveByQuery[${qid}, FALSE]
			indexref:Collapse
			LavishScript:FreeQuery[${qid}]
		}
	}

	function Stack()
	{
		; Wait before StackAll to ensure window is active and ready.
		wait 10
		Inventory.${This.ObjectName}:StackAll
		wait 5
	}

	method DebugPrintInvData()
	{
		variable weakref MyThis = This

		echo "Object: Inventory.${This.ObjectName}"
		echo " IsActive      : ${Inventory.${This.ObjectName}.IsActive}"
		echo " MyID          : ${InvID}   MyName         : ${InvName}   Location: ${InvLocation}"
		echo " ItemID        : ${MyThis.ItemID}   Name          : ${MyThis.Name}"
		echo " IsInRange     : ${MyThis.IsInRange}"
		echo " HasCapacity   : ${MyThis.HasCapacity}"
		if (${MyThis.HasCapacity})
		{
			echo " Capacity      : ${MyThis.Capacity.Precision[2]}  UsedCapacity  : ${MyThis.UsedCapacity.Precision[2]}"
		}
		if (${Current.LocationFlagID} > 0)
		{
			echo " LocationFlag  : ${MyThis.LocationFlag} LocationFlagID: ${MyThis.LocationFlagID}"
		}
	}
}

/*
	This is initialized in EVEBot as a global variable "Inventory"
	Cargos may be accessed as follows

	; Open inventory window and attempt to activate appropriate child
	; Set Inventory.Current to Inventory.Ship
	call Inventory.Ship.Activate

	; Check if Ship is current (meaning the above succeeded)
	if ${Inventory.Ship.IsCurrent} ; Note you can also test ${Return} from the Activate call
	{
		; From here you can access it as
		Inventory.Ship.Capacity
		OR
		Inventory.Current.Capacity
	}
*/
objectdef obj_Inventory inherits obj_BaseClass
{
	variable weakref Current
	variable obj_EVEWindow_Proxy ShipCargo
	variable obj_EVEWindow_Proxy ShipFleetHangar
	variable obj_EVEWindow_Proxy ShipGeneralMiningHold
	variable obj_EVEWindow_Proxy ShipDroneBay

	variable obj_EVEWindow_Proxy StationHangar
	variable obj_EVEWindow_Proxy StationCorpHangars
	variable obj_EVEWindow_Proxy CorporationDeliveries

	variable obj_EVEWindow_Proxy EntityFleetHangar

	;variable obj_EVEWindow_Proxy EntityContainer

	variable set IDRequired

	method Initialize()
	{
		LogPrefix:Set["${This.ObjectName}"]

		ShipCargo:SetLocation[ShipCargo]
		ShipFleetHangar:SetLocation[ShipFleetHangar]
		ShipGeneralMiningHold:SetLocation[ShipGeneralMiningHold]
		ShipDroneBay:SetLocation[ShipDroneBay]
		StationHangar:SetLocation[StationItems]
		StationCorpHangars:SetLocation[StationCorpHangars]
		CorporationDeliveries:SetLocation[StationCorpDeliveries]
		EntityFleetHangar:SetLocation[ShipFleetHangar]
		;EntityContainer - Only uses ID

		IDRequired:Add["StationItems"]
		IDRequired:Add["StationCorpHangars"]
		IDRequired:Add["StationCorpDeliveries"]
		IDRequired:Add["EntityFleetHangar"]

		Logger:Log["${LogPrefix}: Initialized", LOG_MINOR]
	}

	method Shutdown()
	{
	}

	member:bool IsSettling()
	{
		if ${This.ShipCargo.LastMakeActiveAt} > 0 && ${Script.RunningTime} < ${Math.Calc[${This.ShipCargo.LastMakeActiveAt} + ${This.ShipCargo.MakeActiveSettleMS}]}
		{
			return TRUE
		}

		if ${This.ShipFleetHangar.LastMakeActiveAt} > 0 && ${Script.RunningTime} < ${Math.Calc[${This.ShipFleetHangar.LastMakeActiveAt} + ${This.ShipFleetHangar.MakeActiveSettleMS}]}
		{
			return TRUE
		}

		if ${This.ShipGeneralMiningHold.LastMakeActiveAt} > 0 && ${Script.RunningTime} < ${Math.Calc[${This.ShipGeneralMiningHold.LastMakeActiveAt} + ${This.ShipGeneralMiningHold.MakeActiveSettleMS}]}
		{
			return TRUE
		}

		if ${This.EntityFleetHangar.LastMakeActiveAt} > 0 && ${Script.RunningTime} < ${Math.Calc[${This.EntityFleetHangar.LastMakeActiveAt} + ${This.EntityFleetHangar.MakeActiveSettleMS}]}
		{
			return TRUE
		}

		return FALSE
	}

	function Open()
	{
		if !${EVEWindow[Inventory](exists)}
		{
			Logger:Log["Opening Inventory..."]
			EVE:Execute[OpenInventory]
			wait 2
			if !${EVEWindow[Inventory](exists)}
			{
				Logger:Log["Opening Inventory (taking longer than usual)..."]
				wait 10
				if !${EVEWindow[Inventory](exists)}
				{
					Logger:Log["Opening Inventory (taking longerer than usual)..."]
					wait 10
				}
			}
		}
	}

	method Close()
	{
		EVEWindow[Inventory]:Close
	}

	; Delegates Stack() to the currently active inventory window
	; This allows calling "call Inventory.Current.Stack" to work correctly
	function Stack()
	{
		if ${Inventory.ShipCargo.IsCurrent}
		{
			call Inventory.ShipCargo.Stack
		}
		elseif ${Inventory.ShipFleetHangar.IsCurrent}
		{
			call Inventory.ShipFleetHangar.Stack
		}
		elseif ${Inventory.ShipGeneralMiningHold.IsCurrent}
		{
			call Inventory.ShipGeneralMiningHold.Stack
		}
		elseif ${Inventory.ShipDroneBay.IsCurrent}
		{
			call Inventory.ShipDroneBay.Stack
		}
		elseif ${Inventory.StationHangar.IsCurrent}
		{
			call Inventory.StationHangar.Stack
		}
		elseif ${Inventory.StationCorpHangars.IsCurrent}
		{
			call Inventory.StationCorpHangars.Stack
		}
		elseif ${Inventory.CorporationDeliveries.IsCurrent}
		{
			call Inventory.CorporationDeliveries.Stack
		}
		elseif ${Inventory.EntityFleetHangar.IsCurrent}
		{
			call Inventory.EntityFleetHangar.Stack
		}
		else
		{
			Logger:Log["${LogPrefix}.Stack: No current inventory window active", LOG_WARNING]
		}
	}

	; Delegates GetItems to the currently active inventory window
	; This allows calling "Inventory.Current:GetItems[...]" to work correctly
	method GetItems(weakref ItemIndex, string QueryFilter)
	{
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.ShipCargo:GetItems[ItemIndex, "${QueryFilter}"]
		}
		elseif ${Inventory.ShipFleetHangar.IsCurrent}
		{
			Inventory.ShipFleetHangar:GetItems[ItemIndex, "${QueryFilter}"]
		}
		elseif ${Inventory.ShipGeneralMiningHold.IsCurrent}
		{
			Inventory.ShipGeneralMiningHold:GetItems[ItemIndex, "${QueryFilter}"]
		}
		elseif ${Inventory.ShipDroneBay.IsCurrent}
		{
			Inventory.ShipDroneBay:GetItems[ItemIndex, "${QueryFilter}"]
		}
		elseif ${Inventory.StationHangar.IsCurrent}
		{
			Inventory.StationHangar:GetItems[ItemIndex, "${QueryFilter}"]
		}
		elseif ${Inventory.StationCorpHangars.IsCurrent}
		{
			Inventory.StationCorpHangars:GetItems[ItemIndex, "${QueryFilter}"]
		}
		elseif ${Inventory.CorporationDeliveries.IsCurrent}
		{
			Inventory.CorporationDeliveries:GetItems[ItemIndex, "${QueryFilter}"]
		}
		elseif ${Inventory.EntityFleetHangar.IsCurrent}
		{
			Inventory.EntityFleetHangar:GetItems[ItemIndex, "${QueryFilter}"]
		}
		else
		{
			Logger:Log["${LogPrefix}.GetItems: No current inventory window active", LOG_WARNING]
		}
	}

	; NOTE: Items() member removed - cannot return index:item from member function
	; Use GetItems[weakref, query] to populate an index:item instead

	; Returns FALSE/0, or the ID of the opened entity
	function OpenEntityFleetHangar(int64 ID)
	{
		call This.Open

		variable entity EntityToOpen
		EntityToOpen:Set[${ID}]
		if !${EntityToOpen(exists)} || ${EntityToOpen.ID} <= 0
		{
			Logger:Log["${LogPrefix}.OpenEntityIDFleetHangar: ${ID} doesn't exist", LOG_WARNING]
			return FALSE
		}

		if ${EntityToOpen.Distance} > 2500
		{
			Logger:Log["${LogPrefix}.OpenEntityIDFleetHangar: ${EntityToOpen.ID} (${EntityToOpen.Name}) is too far away (${EntityToOpen.Distance})", LOG_WARNING]
			return FALSE
		}

		;if !${EntityToOpen.HasFleetHangars}
		;{
		;	Logger:Log["${LogPrefix}.OpenEntityIDFleetHangar: ${EntityToOpen.ID} (${EntityToOpen.Name}) doesn't have fleet hangars", LOG_WARNING]
		;	return
		;}

		Logger:Log["${LogPrefix}.OpenEntityIDFleetHangar: Opening fleet hangar of ${EntityToOpen.ID} (${EntityToOpen.Name})", LOG_MINOR]
		EntityToOpen:Open
		wait 10
		return ${EntityToOpen.ID}
	}
}

/*

Notes:
Corporation Hangars and Member Hangars are twisties only, not containers

Under Corp Member Hangar, each member
	StationCorpMember charid flagHangar 4

Ship Hangar:
	StationShips stationid flagHangar 4
Under Ship Hangar, each shiup
	ShipCargo shipid flagCargo 5

StationCorpDeliveries stationid flagCorpMarket 62
StructureItemHangar
StructureShipHangar

Note - each of the below also applies to the ships in the ship hangar, given the right id
ShipCargo itemid flagCargo 5
ShipGeneralMiningHold itemid flagSpecializedOreHold 134
ShipFleetHangar itemid flagFleetHangar 155
ShipMaintenanceBay itemid flagShipHangar 90
ShipDroneBay itemid flagDroneBay 87


* The "container" entry within the eveinventorywindow with the label "Corporation hangars" is now accessible and must be
  made active before the individual corporation folders are available.  For example:
	if !${EVEWindow[Inventory].ChildWindow[${Me.StationID}, StationCorpHangar, "Folder1"](exists)}
		EVEWindow[Inventory].ChildWindow[${Me.StationID}, StationCorpHangars]:MakeActive

TODO
 Find all :Open and :GetCargo or .*Cargo[..] calls for Entity-based work.

*/
