
--[Generic functions]

--Debug print to console
fn printc tString =
(
	--Print as string to print arrays and other things too
	if (s_print == true) do (print(tString as string))
)

--Window resize function for rollouts
fn resizeWindow tState tRollout =
(
    if (tState == true) then
    (
		UI_Base.height += tRollout.height
		ToolBoy.height += tRollout.height
    )
    else
    (
		UI_Base.height -= tRollout.height
		ToolBoy.height -= tRollout.height
    )
)

--Standardized copying function
fn CopyNodes tArray type &Container =
(
	--Copies node(s) and returns them in supplied container
	maxOps.cloneNodes tArray cloneType:type newNodes:&tCopies #nodialog

	aCopies = tCopies as array

	if (aCopies.count > 1) then
	(
		Container = aCopies	
	)
	else
	(
		Container = aCopies[1]
	)	
)	

--Collects nodes based on prefix
fn getPrefixObjects prefix = 
(
	free nodeList
	
	local storedSelection = (selection as array)
	local tempArray = #()

	select $*

	for obj in selection do
	(
		if matchPattern obj.name pattern:((prefix as string) + "*") == true do
		(
			append tempArray obj
			--print("Appended " + obj.name as string + " to list.")
		)
	)
	
	local tArray = for i in tempArray collect i
	nodeList = for i in tempArray collect i

	clearSelection()
	select(storedSelection)

	return tArray
)

--Generic node collecting form with prefix function
fn collectObjects prefixIndex = 
(
	--print("Cleaning existing node list")
	free nodeList

	local tempArray = #()

	if (selection.count == 0) then
	(
		if (s_usePrefix == true) then
		(
			tempArray = getPrefixObjects(prefixIndex)
		)
		else
		(
			local tryAgain = queryBox "Nothing selected, use prefix and try again?" title:"Nothing selected!"
			
			if (tryAgain == true) then
			(
				tempArray = getPrefixObjects(prefixIndex)

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
fn getChildren obj = 
(
	if (obj == unsupplied) do (obj = selection[1])
	--Select children can also be done with "Cntrl + PgDown"
	clearSelection()
	select obj
	--execute ("$'" + (obj.name) + "'/*/.../*")

	for obj in selection do
	(
		if obj.children != undefined do
		(
			selectmore obj.children
		)
	)

	return (selection as array)
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
	if (tArray == undefined) do 
	(
		print("No objects, exiting sort.")
		return()
	)

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
		--print("Obj: " + (shuffleArray[i][1].name as string) + " i: " + (shuffleArray[i][2] as string))
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

		findItem
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
	
	local scaleArray = sortToHierarchy(tArray)

	with redraw off 
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