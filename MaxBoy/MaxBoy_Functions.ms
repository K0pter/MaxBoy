
--[Generic functions]

--Debug print to console
fn printc tString =
(
	if (PrintToConsole == undefined) do (return())
	--Print as string to print arrays and other things too
	try
	(
		if (PrintToConsole == true) do (print(tString))
	)catch(print("Print is goofed"))
	--if (s_print == true) do (print(tString as string))
)

fn validArray tArray =
(
	local x = false

	if (classOf tArray != Array) then
	(
		x = false
	)
	else
	(
		if (tArray == undefined) then
		(
			x = false
		)
		else
		(
			if (tArray.count == 0) then
			(
				x = false
			)
			else
			(
				x = true
			)
		)
	)

	if (x == true) then
	(
		return(true)
	)
	else
	(
		printc("No objects, exiting sort.")
		return(false)
	)
)

fn RootParent tNode =
(
	local tParent = tNode.parent

	local foundParent = false

	while(foundParent == false) do
	(
		if (tParent.parent != undefined) then
		(
			tParent = tParent.parent
		)
		else
		(
			foundParent = true
		)
	)

	return tParent
)

--Standardized copying function
fn CopyNodes collection:(selection as array) type:#copy uniqueNames:false =
(
	if (classOf collection == Array) then
	(
		--Copies node(s)
		maxOps.cloneNodes (collection as array) cloneType:type newNodes:&tCopies #nodialog
	)
	else
	(
		--Copies node
		maxOps.cloneNodes (collection as array) cloneType:type newNodes:&tCopies #nodialog
	)

	local aCopies = tCopies as array

	--Rename copied objects names to original's names
	if (uniqueNames == false) do
	(
		for i = 1 to aCopies.count do
		(
			aCopies[i].name = collection[i].name
		)
	)

	--Returns nodes in supplied container
	return(aCopies)
)

--Generic node collecting form with prefix function
fn collectObjects prefix:"" =
(
	--print("Cleaning existing node list")
	free nodeList

	local tempArray = #()

	if (selection.count == 0) then
	(
		if (s_usePrefix == true) then
		(
			tempArray = getPrefixObjects pre:prefix
		)
		else
		(
			local tryAgain = queryBox "Nothing selected, use prefix and try again?" title:"Nothing selected!"

			if (tryAgain == true) then
			(
				tempArray = getPrefixObjects pre:prefix

				if (tempArray.count == 0) do
				(
					messageBox "No objects with given prefix found!" title:"No prefix objects!"
				)
			)
			else
			(
				clearListener()
				messageBox "No objects with given prefix found!" title:"No prefix objects!"
				print("No objects with given prefix found!")
				return()
			)
		)
	)
	else
	(
		for obj in selection do
		(
			append tempArray obj
		)
	)

	local tArray = for i in tempArray collect i

	return tArray
)

--Selects all children under supplied node
fn getChildren obj: =
(
	max create mode

	local selectedChildren = #()

	with redraw off
	(
		if (obj == unsupplied) then
		(
			--Sort selection to hierarchy and get top parent
			local sortArr = selection
			local indexArr = #()

			sortToHierarchy &sortArr &indexArr

			if (isValidNode sortArr[1]) then
			(
				append selectedChildren sortArr[1]
			)
			else
			(
				printc("GetChildren :: Couln't proceed, hierarchy top is undefined")
				return()
			)
		)
		else
		(
			if (isValidNode obj) then
			(
				append selectedChildren obj
			)
			else
			(
				printc("GetChildren :: Couln't proceed, obj is undefined")
				return()
			)
		)

		do
		(
			local nn = false

			for s in selectedChildren do
			(
				if (isValidNode s) do
				(
					for c in s.children do
					(
						if (isValidNode c) do
						(
							if (appendIfUnique selectedChildren c) do
							(
								--If new node was added to seleciton, keep searching
								nn = true
							)
						)
					)
				)
			)
		)
		while ( nn == true )

		return selectedChildren
	)
)

--Cleans undefined entries out of an array
fn cleanArray tArray =
(
	local whileIndex = 1

	while(findItem tArray undefined != 0) do
	(
		if (tArray[whileIndex] == undefined) do
		(
			deleteItem tArray whileIndex
			whileIndex -= 1
		)

		whileIndex += 1

		if (whileIndex > tArray.count) do (whileIndex = 1)
	)

	return tArray
)

--Sorts an hierarchy based on hierarchy depth
fn sortToHierarchy &tArray &tIndex =
(
	if (validArray(tArray) == false) do (return())

	local shuffleArray = #()

	for i = 1 to tArray.count do
	(
		local o = tArray[i]

		local p = o --Parent ref (starts with current object)
		local pc = -1 --Parent count

		local searchParent = true

		while (searchParent == true) do
		(
			printc("While:STH_searchParent")

			if (p.parent != undefined) then
			(
				p = p.parent
				pc += 1
			)
			else
			(
				local tEntry = #(o, pc)

				append shuffleArray tEntry

				searchParent = false
			)
		)
	)

	local si = 0 --Shuffle index
	local foundOne = false

	while(si != -1) do
	(
		printc("While:STH_shuffleArray_Sort")

		si += 1

		if (si == shuffleArray.count) then
		(
			if (foundOne == false) then
			(
				si = -1
				exit
			)
			else
			(
				si = 0
				foundOne = false
				continue
			)
		)
		else
		(
			if (shuffleArray[si] != undefined) do
			(
				if (shuffleArray[si + 1][2] < shuffleArray[si][2]) do
				(
					foundOne = true

					local tempShuffle = shuffleArray[si]

					shuffleArray[si] = shuffleArray[si + 1]
					shuffleArray[si + 1] = tempShuffle
				)
			)
		)
	)

	while(shuffleArray[1][2] > 1) do
	(
		printc("While:STH_shuffleArray_SubtractToOne")

		for i = 1 to shuffleArray.count do
		(
			printc(shuffleArray[i][2])
			shuffleArray[i][2] -= 1
		)
	)

	local oArray = #()
	local iArray = #()

	for i = 1 to shuffleArray.count do
	(
		printc("Obj: " + (shuffleArray[i][1].name as string) + " i: " + (shuffleArray[i][2] as string))
		oArray[i] = shuffleArray[i][1]
		iArray[i] = shuffleArray[i][2]
	)

	tArray = oArray
	tIndex = iArray

	--return tArray
)

--Returns an array of index depths for a hierarchy at the same positions
fn getHierarchyIndex tArray =
(
	if (tArray == undefined) do (return())

	local indexArray = #() --Array to hold what depth the node is located in

	local wArray = tArray
	local sortedArray = #()
	local shitArray = #()

	sortToHierarchy &sortedArray &shitArray

	local testArray = #()

	for i = 1 to sortedArray.count do
	(
		local o = sortedArray[i]

		local p = o --Parent
		local pc = 1 --Parent count

		testArray[i] = o.children

		--Fetch reference position in sorted array
		local pos = findItem sortedArray o

		--Set cycles for maximum depth check
		for q = 1 to 100 do
		(
			if (p.parent != undefined) then
			(
				p = p.parent
				pc += 1
			)
			else
			(
				--indexArray[pos] = pc
				insertItem pc indexArray pos
				exit
			)
		)
	)

	local indexSorted = cleanArray(indexArray)

	while(indexSorted[1] != 1) do
	(
		for i = 1 to indexSorted.count do
		(
			indexSorted[i] -= 1
		)
	)

	print(indexSorted)
	--Return supplied array reordered
	return(indexSorted)
)

fn getHierarchy tArray =
(
	local sortArray = #()
	local indexArray = getHierarchyIndex(tArray)

	for o in tArray do
	(
		append sortArray (o.children)
	)

	for i = 1 to sortArray.count do
	(
		--print("Obj: " + tArray[i] as string)
		--print("Children: " + sortArray[i] as string)

		--findItem
	)

	--print(sortArray)
)

--Rotates only the pivot for an object using an Euler rotation
fn RotatePivotOnly obj _rotation =
(
	--obj.rotation = _rotation
	animate off in coordsys local
	(
		obj.objectoffsetrot *= (_rotation as quat)
	)
)

--Sets the scale to [1,1,1] and keeps the hierarchy intact
fn fn_resetScales tArray =
(
	--clearListener()
	print("Resetting scales!")

	if (validArray(tArray) == false) do (return())

	local indexNull = #()
	local scaleArray = tArray

	sortToHierarchy &scaleArray &indexNull

	with redraw off
	with undo off
	(
		--for d in scaleArray do (format "node: %; \n" d)
		local parentArray = #()

		--Collect parents and unparent, to avoid cycles
		for o in scaleArray do
		(
			append parentArray o.parent
			o.parent = undefined
		)

		--Reset scales when all nodes are free floating
		for o in scaleArray do
		(
			ResetScale o
		)

		--Reparent when scales are reset
		for i = 1 to scaleArray.count do
		(
			scaleArray[i].parent = parentArray[i]
		)

		print("Scaling operation is done!")
	)
)

-- Calculates the axis-aligned bounding box corners of an object
fn getAABBoxPoints obj =
(
	local aabbPoints = #()

	-- Get minimum and maximum bounding box coordinates
	local bbMax = obj.max
	local bbMin = obj.min

	-- Build the axis-aligned bounding box corners

	append aabbPoints (Point3 bbMax.x bbMax.y bbMax.z)	-- top-right-front corner
	append aabbPoints (Point3 bbMax.x bbMin.y bbMax.z)	-- top-right-back corner
	append aabbPoints (Point3 bbMin.x bbMin.y bbMax.z)	-- top-left-back corner
	append aabbPoints (Point3 bbMin.x bbMax.y bbMax.z)	-- top-left-front corner

	append aabbPoints (Point3 bbMax.x bbMax.y bbMin.z)	-- bottom-right-front corner
	append aabbPoints (Point3 bbMax.x bbMin.y bbMin.z)	-- bottom-right-back corner
	append aabbPoints (Point3 bbMin.x bbMin.y bbMin.z)	-- bottom-left-back corner
	append aabbPoints (Point3 bbMin.x bbMax.y bbMin.z)	-- bottom-left-front corner

	return aabbPoints
)

-- Calculates the oriented bounding box corners of an object
fn getOBBoxPoints obj =
(
	local obbPoints = #()

	-- World-space transform
	local worldSpaceXform = obj.transform

	-- World-space to object-space transform
	local objectSpaceXform = inverse worldSpaceXform

	-- Transform the object from world-space to object-space
	obj.transform *= objectSpaceXform

	-- Get the object-space axis-aligned bounding box corners
	aabbPoints = getAABBoxPoints obj

	-- Transform back to world-space
	obj.transform = worldSpaceXform

	-- Transform the eight corners from object-space to world-space
	for pt in aabbPoints do (
		append obbPoints (pt * worldSpaceXform)
	)

	return obbPoints
)

--Returns a relatively scaled factor to an object based on it's bounds
fn getRelativeScale obj =
(
	local AABB = getOBBoxPoints(obj)

	--Get the hypotenuse of the bounding box
	local pt1 = AABB[1]--Top right corner
	local pt2 = AABB[7]--Bottom left corner

	local pt3 = AABB[4]--Top left corner
	local pt4 = AABB[6]--Bottom right corner

	local factor_1 = distance pt1 pt2
	local factor_2 = distance pt3 pt4

	local factor = (factor_1 + factor_2) / 2

	return factor
)

--Return a programmatic path from "regular" explorer path string
fn convertToPath convertPath =
(
	local splitPath = filterString convertPath "\\"

	local filteredPath = ""

	for i = 1 to splitPath.count do
	(
		filteredPath = (filteredPath + splitPath[i])

		if (i != splitPath.count) do
			filteredPath += ("\\\\")
	)

	return filteredPath
)

--Fetch script location
fn getScriptLocation srcName scrName =
(
	local ScriptName = (scrName + ".ms")
	local FileName = srcName

	local FilteredPath = replace FileName (FileName.count - ScriptName.count + 1) (ScriptName.count) ""

	return FilteredPath
)

--Locate accessory based on a couple parameters
fn LocateAccessory sel:$* pre:"" returnChild:false =
(
	local searchSelection = sel

	if (pre != "") do
	(
		--Check prefix
		for o in searchSelection do
		(
			local searchResult = MatchPattern o.name pattern:(pre as string + "*") ignoreCase: false

			if (searchResult == true) do
			(
				--print("Found rig based on prefix >> " + o.name)
				return(o)
			)
		)
	)

	--print("Didn't find anything from prefix...")

	--Try and find based on naming
	for o in searchSelection do
	(
		local intelSearch = #("weapon", "item", "accessory", "w_", "weap_", "wpn_", "itm_", "weapon_bone")

		for str in intelSearch do
		(
			local searchResult = MatchPattern o.name pattern: (str as string + "*") ignoreCase: true

			if (searchResult == true) do
			(
				if (o.parent == undefined) do
				(
					continue()
					--print("Found object, but didn't have root >> " + o.name)
				)

				--Check if parent is named as potential root
				local parentResult = MatchPattern o.parent.name pattern:("root*") ignoreCase: true

				if (parentResult == true) then
				(
					--print("Found rig in intelSearch >> " + o.name)

					if (returnChild == true) then
					(
						return(o)
					)
					else
					(
						return(o.parent)
					)
				)
				else
				(
					--print("Found object, but didn't have root >> " + o.name)
				)
			)
		)
	)
)

--Locate and select all objects in collection or scene by supplied prefix
fn getPrefixObjects pre:"" sel:$* allowMeshes:false =
(
	local searchSelection = sel
	local nodeSelection = #()

	for o in searchSelection do
	(
		if (matchPattern o.name pattern:(pre + "*")) do
		(
			if ((allowMeshes == false) and (superclassOf o != GeometryClass)) do
			(
				append nodeSelection o
			)
		)
	)

	return nodeSelection
)

--Custom freeze transform function
fn freezetransforms obj =
(
  local curobj = obj

  if classof curobj.rotation.controller != rotation_layer do
  (
    -- freeze rotation
    curobj.rotation.controller = euler_xyz()
    curobj.rotation.controller = rotation_list()
    curobj.rotation.controller.available.controller = euler_xyz()

    -- rename rotation controllers
    curobj.rotation.controller.setname 1 "frozen rotation"
    curobj.rotation.controller.setname 2 "zero euler xyz"

    -- set the new rotation controller as the active controller
    curobj.rotation.controller.setactive 2
  )

  if classof curobj.position.controller != position_layer do
  (
    -- freeze position
    curobj.position.controller = bezier_position()
    curobj.position.controller = position_list()
    curobj.position.controller.available.controller = position_xyz()

    -- rename rotation controllers
    curobj.position.controller.setname 1 "frozen position"
    curobj.position.controller.setname 2 "zero pos xyz"

    -- set the new position controller as the active controller actual
    curobj.position.controller.setactive 2

    -- reset the position of the actual position controller to zero
    curobj.position.controller[2].x_position = 0
    curobj.position.controller[2].y_position = 0
    curobj.position.controller[2].z_position = 0
  )
)

--Get all meshes in supplied array
fn filterformeshes &filterarray =
(
	local tempfilterarray = #()

	for i = 1 to filterarray.count do
	(
		--if (classof filterarray[i] == editable_poly or classof filterarray[i] == editable_mesh) do
		if (superclassof filterarray[i] == geometryclass) do
		(
			append tempfilterarray filterarray[i]
		)
	)

	return tempfilterarray
)

--Remove prefixes from names
fn stripPrefixes &collection =
(
	if (collection == undefined) do (print("StripPrefixes :: Collection is undefined!") return())

	for o in collection do
	(
		if (isValidNode o) do
		(
			if (matchPattern o.name pattern:("*:*")) do
			(
				local i = findString o.name ":"

				o.name = replace o.name 1 i ""
			)
		)
	)
)
