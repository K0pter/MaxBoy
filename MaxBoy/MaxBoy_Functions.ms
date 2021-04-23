
--[ Generic types ]
global WorldAxis = #("X-Positive", "Y-Positive", "Z-Positive", "X-Negative", "Y-Negative", "Z-Negative")

--[ Generic functions ]

--Debug print to console
fn printc tString =
(
	if (GP_PrintToConsole == undefined) do (return())
	--Print as string to print arrays and other things too
	try
	(
		if (GP_PrintToConsole == true) do (print(tString))
	)catch(print("Print is goofed"))
	--if (s_print == true) do (print(tString as string))
)

--Checks if an array is valid
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

--Walks up a hierarchy from provided node until no parent of current parent is found, then returns that node
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

--Returns string without last character attached
fn RemoveLastChar str =
(
	if (classOf str != string) do ( print("RemoveLastChar :: Supplied variable isn't of type string!"); return("") )

	local strCopy = (copy str)
	return (substring strCopy 1 (strCopy.count - 1) )
)

--Match pattern with multiple patterns (matchAll is used if we want it to pass all pattern checks)
fn MatchPatternMultiple str:"" patterns:#("") matchAll:false &ind: =
(
	local currentIndex = 0

	--Go through all patterns
	for p in patterns do
	(
		currentIndex += 1

		--If we have a match, then
		if (MatchPattern str pattern:p == true) then
		(
			--If we don't have to match all patterns, return on first match
			if (matchAll == false) do
			(
				if (ind != unsupplied) do (ind = currentIndex)

				return(p)
			)
		)
		else
		(
			--If we HAVE to match all patterns, fail on first mismatch
			return(false)
		)
	)

	--Fail if we haven't found a single match
	return(false)
)

--Standardized copying function
fn CopyNodes collection: type:#copy uniqueNames:false fOp:false =
(
	if (collection == unsupplied) do (collection = (selection as array))
	if (collection == undefined) do ( print("CopyNodes :: Undefined collection") return(undefined) )
	if (classOf collection != Array) do ( print("CopyNodes :: Collection is not of type array") return(undefined) )

	local baseQueryResult = false

	--Check if we want to stop or ignore incompatible node types
	for i = 1 to collection.count do
	(
		local n = collection[i]

		if (ClassOf n == CATBone) do
		(
			--Only question user if we haven't already asked
			if (baseQueryResult == false) do
			(
				local queryResult = queryBox "Current selection contains a node(s) of uncompatible type for copy operation, do you wish to continue without them?" title:"Invalid node type"
			)

			if (queryResult == true or baseQueryResult == true) then
			(
				--Default the next answer to true if we're set on continuing the operation
				baseQueryResult = true

				--Remove invalid node from collection
				deleteItem collection i
			)
			else
			(
				--Stop and enable redraw
				EnableSceneRedraw()
				print("Stopping copy operation...")
				return()
			)
		)
	)

	--Safe wrap operation
	try
	(
		--Speed up operation
		if (fOp == true) do (DisableSceneRedraw())

		--Copy nodes operation
		maxOps.cloneNodes (collection as array) cloneType:type newNodes:&tCopies #nodialog

		local aCopies = tCopies as array

		--Rename copied objects names to original's names
		if (uniqueNames == false) do
		(
			for i = 1 to aCopies.count do
			(
				if (aCopies[i] != undefined and collection[i] != undefined) do
				(
					aCopies[i].name = collection[i].name
				)
			)
		)

		if (fOp == true) do (EnableSceneRedraw())

		--Returns nodes in supplied container
		return(aCopies)
	)
	catch
	(
		EnableSceneRedraw()

		print("CopyNodes :: Fatal error when attempting to copy nodes!")
		throw()
	)
)

--Selects all children under supplied node
fn GetChildren obj: =
(
	--max create mode

	local selectedChildren = #()

	DisableSceneRedraw()

	try
	(
		if (obj == unsupplied) then
		(
			--Sort selection to hierarchy and get top parent
			local sortArr = GetCurrentSelection()

			SortToHierarchy &sortArr

			if (isValidNode sortArr[1]) then
			(
				append selectedChildren sortArr[1]
			)
			else
			(
				printc("GetChildren :: Couldn't proceed, hierarchy top is undefined")
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
				printc("GetChildren :: Couldn't proceed, obj is undefined")
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

		EnableSceneRedraw()

		return selectedChildren
	)
	catch
	(
		EnableSceneRedraw()

		print("GetChildren :: Something failed!")
	)
)

--Cleans undefined entries out of an array
fn CleanArray tArray =
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
fn SortToHierarchy &tArray =
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
			--printc("While:STH_searchParent")

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
		--printc("While:STH_shuffleArray_Sort")

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
		--printc("While:STH_shuffleArray_SubtractToOne")

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
		--printc("Obj: " + (shuffleArray[i][1].name as string) + " i: " + (shuffleArray[i][2] as string))
		oArray[i] = shuffleArray[i][1]
		iArray[i] = shuffleArray[i][2]
	)

	--iArray is an array holding the depth of the node's position in tArray

	tArray = oArray
)

--Returns an array of index depths for a hierarchy at the same positions
fn GetHierarchyIndex tArray =
(
	if (tArray == undefined) do (return())

	local indexArray = #() --Array to hold what depth the node is located in

	local wArray = tArray
	local sortedArray = #()

	SortToHierarchy &sortedArray

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

	local indexSorted = CleanArray(indexArray)

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

fn GetHierarchy tArray =
(
	local sortArray = #()
	local indexArray = GetHierarchyIndex(tArray)

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
fn ResetScales tArray =
(
	--clearListener()
	print("Resetting scales!")

	if (validArray(tArray) == false) do (return())

	local scaleArray = tArray

	SortToHierarchy &scaleArray

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
fn GetAABBoxPoints obj =
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
fn GetOBBoxPoints obj =
(
	local obbPoints = #()

	-- World-space transform
	local worldSpaceXform = obj.transform

	-- World-space to object-space transform
	local objectSpaceXform = inverse worldSpaceXform

	-- Transform the object from world-space to object-space
	obj.transform *= objectSpaceXform

	-- Get the object-space axis-aligned bounding box corners
	aabbPoints = GetAABBoxPoints obj

	-- Transform back to world-space
	obj.transform = worldSpaceXform

	-- Transform the eight corners from object-space to world-space
	for pt in aabbPoints do (
		append obbPoints (pt * worldSpaceXform)
	)

	return obbPoints
)

--Returns a relatively scaled factor to an object based on it's bounds
fn GetRelativeScale obj =
(
	local AABB = GetOBBoxPoints(obj)

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
fn ConvertToPath convertPath =
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

fn ConvertPathToString convertPath =
(
	local splitPath = filterString convertPath "\\\\"

	local filteredPath = ""

	for i = 1 to splitPath.count do
	(
		filteredPath = (filteredPath + splitPath[i])

		if (i != splitPath.count) do
			filteredPath += ("\\")
	)

	return filteredPath
)

--Fetch script location
fn GetScriptLocation srcName scrName =
(
	local ScriptName = (scrName + ".ms")
	local FileName = srcName

	local FilteredPath = replace FileName (FileName.count - ScriptName.count + 1) (ScriptName.count) ""

	return FilteredPath
)

--Remove prefixes from nodes
fn StripPrefixes &collection =
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

--Remove prefixes from strings
fn StripPrefixesInStrings &collection =
(
	if (collection == unsupplied) do (print("StripPrefixesInStrings :: Collection is unsupplied!") return())

	local tempArray = #()

	for o in collection do
	(
		local tempString = o

		if (matchPattern tempString pattern:("*:*")) do
		(
			local i = findString tempString ":"
			tempString = replace tempString 1 i ""
		)

		append tempArray tempString
	)

	collection = copy tempArray #nomap
)

--Bool wether or no the provided node has a prefix in its name
fn HasPrefix n: =
(
	--Does name contain a prefix symbol?
	return (matchPattern n.name pattern:("*:*"))
)

--Isolate and return prefix from node(s)
fn GetPrefix sel: =
(
	local tArray = #()
	local prefixes = #()

	if (classOf(sel) == Array) then ( join tArray sel )	else ( append tArray sel )

	for o in tArray do
	(
		--Only attempt prefix retrieval if a colon exists in name
		if (HasPrefix n:o) do
		(
			local prefixIndex = findString o.name ":"

			if (prefixIndex != undefined) do
			(
				append prefixes (substring (o.name) 1 prefixIndex)

				/*
				local tPre = ""
				local tempName = copy o.name

				for i = 1 to tempName.count do
				(
					local char = tempName[i]

					tPre += char

					if (char == ":") do
					(
						append prefixes tPre
					)
				)
				*/
			)
		)
	)

	return prefixes
)

--Locate and select all objects in collection or scene by supplied prefix
fn GetPrefixObjects pre:"" sel:$* allowMeshes:false =
(
	local searchSelection = sel
	local nodeSelection = #()

	printc("Found prefix: " + pre)

	for o in searchSelection do
	(
		if (o != undefined) do
		(
			if (MatchPattern o.name pattern:(pre + "*")) do
			(
				if (superclassOf o == GeometryClass and allowMeshes == false) then
				(
					--Ignore meshes if not allowed
				)
				else
				(
					append nodeSelection o
				)
			)
		)
	)

	return nodeSelection
)

--Find a prefixed node within selection
fn FindPrefixedObject n: sel:$* ignoreCasing:false ex:false strippedArray:undefined =
(
	if ((n == undefined) or (n == unsupplied) or (n == "")) do
	(
		--print("FindPrefixedObject :: <N> parameter is null!")
		return(undefined)
	)

	local originalArray = (sel as array)

	if (strippedArray == undefined) do
	(
		strippedArray = #()
		for o in originalArray do ( append strippedArray (copy (o.name)) )
		StripPrefixesInStrings &strippedArray
	)

	for i = 1 to strippedArray.count do
	(
		local baseName = strippedArray[i]

		if (MatchPattern baseName pattern:n ignoreCase:ignoreCasing exact:ex) do
		(
			--Return node from original array
			return(originalArray[i])
		)
	)

	print("FindPrefixedObject :: Failed finding of >> " + n + " in :: (printed array)")
	--print(strippedArray)

	return(undefined)
)

--Get all prefixes present in scene
fn FindPrefixesInScene sel:$* =
(
	local prefixes = #()

	for o in sel do
	(
		local n = o.name

		if (n != undefined) do
		(
			if (matchPattern n pattern:("*:*")) do
			(
				local i = findString n ":"
				local pre = (substring n 1 i)

				local tryFindPrefix = findItem prefixes pre

				if (tryFindPrefix == 0) do
				(
					append prefixes pre
				)
			)
		)
	)

	return prefixes
)

--Locate accessory based on a couple parameters
fn GetAccessory sel:$* pre:"" returnChild:false =
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

--Locate accessory based on a couple parameters
fn GetRootNodes sel:$* rootNames:#("root", "b_root", "Root", "reference") =
(
	local RootNodes = #()

	--Setup stripped array for faster matching
	local localStrippedArray = #()
	for o in sel do ( append localStrippedArray (copy (o.name)) )
	StripPrefixesInStrings &localStrippedArray

	--Try and find based on naming
	local intelSearch = rootNames

	for str in intelSearch do
	(
		local searchResult = FindPrefixedObject n:str sel:sel strippedArray:localStrippedArray

		if (searchResult != undefined) do
		(
			append RootNodes searchResult
		)
	)

	return RootNodes
)

--Custom freeze transform function
fn FreezeTransforms obj =
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
fn FilterMeshes &filterarray =
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

--Keybaker function
fn BakeKeys collection:(selection as array) rs: re: method:1 keepController:false rev:false ref:undefined &DelayPrintArr: =
(
	--Modes: 1:Regular, 2:Reference, 3:Dummy, 4:Start)
	if (method == 2 and ref == undefined) do
	(
		messageBox "No ref picked! Stopping bake." title:"Error!"
		return()
	)

	if (rs == unsupplied) do (rs = (( normTime 0 as integer ) / ticksperframe))
	if (re == unsupplied) do (re = (( normTime 1 as integer ) / ticksperframe))

	local BakeCollection = collection --Make new array variable based on collection

	with redraw off
	(
		--Take time on how long the process takes
		BakeTimerStart = timeStamp()

		try
		(
			DisableSceneRedraw()

			--Start off with sorting bake collection by hierarchy depth to avoid race issues
			SortToHierarchy &BakeCollection

			global tf = #()--Transform array

			local collectedFirstFrameData = false
			local StartFrameTransforms = #()

			--Initiate copying pass index var
			local copyPass = 0

			for t = rs to re do
			(
				copyPass += 1

				local ObjectData = #()
				local ObjectKeys = #()

				for i = 1 to BakeCollection.count do
				(
					obj = BakeCollection[i]

					if obj != undefined then
					(
						if (collectedFirstFrameData == false) do
						(
							if (method == 4) do
							(
								--Collect first frame transform data and store into array
								at time rs
								(
									local firstFrameTrans = in coordsys world obj.transform
								)

								append StartFrameTransforms firstFrameTrans
							)
						)

						at time t
						(
							local transformAtFrame = in coordsys world obj.transform
						)

						append ObjectData obj
						append ObjectKeys transformAtFrame

						local ObjectPackage = #(ObjectData, ObjectKeys)

						--print("Package: " + ObjectPackage as string)

						tf[copyPass] = ObjectPackage
					)
					else
					(
						printc("Undefined object, ignoring.")
					)
				)

				--After first pass of processing, set to not collect further data
				collectedFirstFrameData = true
			)

			--Are we baking to dummy or no? Reset controllers or make dummies.
			if (method == 3) then
			(
				local bakeDummies = #()--Store temp transform objects into array
				animate off
				--Make dummy objects to apply baked data to--
				for obj in BakeCollection do
				(
					local bd = Point name:("baked_" + obj.name as string) size:10
					bd.transform.controller = prs()
					bd.position.controller = position_XYZ()
					bd.rotation.controller = Euler_XYZ()

					bd.transform = obj.transform

					append bakeDummies bd
				)

				--Transfer temp array of new bake data dummies over to become selection array
				BakeCollection = bakeDummies
			)
			else
			(
				--Fix object controllers--
				for obj in BakeCollection do
				(
					local testResult = true
					--Make sure you're checking a controller and not Matrix3
					try (classOf obj.transform.controller) catch (testResult = false) --Throws error if it's a bad cast

					--print("TestResult: " + testResult as string)
					--print(classOf obj.transform.controller)

					--Did we pass the test?
					if (testResult == true) do
					(
						local testController = false
						local controllersToTest = #(PRS, Link_Constraint, transform_script, XRef_Controller)

						for c in controllersToTest do
						(
							if (classOf obj.transform.controller == c) do ( testController = true )
						)
						--Only do reset operation if controller is of type PRS (Position/Rotation/Scale)
						if ((testController == true) and (keepController == false)) do
						(
							obj.transform.controller = prs()
							obj.position.controller = position_XYZ() --Do this steps to make sure controllers get reset fully
							obj.rotation.controller = Euler_XYZ() --Do this steps to make sure controllers get reset fully
						)
					)
				)
			)

			--Initiate pasting pass index var
			local pastePass = 0

			local virtualStartFrame = rs
			local virtualEndFrame = re
			local stepBasis = 1

			--Flip start/ end frames depending on if we're reversing or not
			if (rev == true) do
			(
				virtualStartFrame = re
				virtualEndFrame = rs
				stepBasis = -1 --Go in reverse in for loop
			)

			/*Debug for loop stepping
			print("start: " + virtualStartFrame as string)
			print("end: " + virtualEndFrame as string)

			for t in virtualStartFrame to virtualEndFrame by stepBasis do
			(
				print("t: " + t as string)
			)
			*/

			--Paste to temp transforms pass--
			for t in virtualStartFrame to virtualEndFrame by stepBasis do
			(
				--print("t: " + t as string)

				--Start from 0 and continue in the arrays from there
				pastePass += 1

				for i = 1 to BakeCollection.count do
				(
					animate off

					in coordsys world
					(
						local getPackage = tf[pastePass]
						local getPackageObject = getPackage[1][i]
						local getPackageFrames = getPackage[2][i]

						--Get object based on name if we're baking to a dummy
						if (method == 3) do
						(
							getPackageObject = getNodeByName("baked_" + getPackage[1][i].name)
						)
						--print(("Selection: " + getPackageObject as string) + (" at frame: " + t as string))

						--Apply fetched transform to object
						at time t
						(
							animate on

							case method of
							(
								1: ( getPackageObject.transform = getPackageFrames ) --Regular
								2: ( getPackageObject.transform = ref.transform ) --Ref
								3: ( getPackageObject.transform = getPackageFrames ) --Dummy
								4: ( getPackageObject.transform = StartFrameTransforms[i] ) --Start
							)
						)
					)
				)
			)

			free bakeDummies
			free ObjectData
			free ObjectKeys
		)
		catch
		(
			EnableSceneRedraw()
			messagebox("BakeKeys :: Fatal error!") title:"Error!"

			throw()
		)

		BakeTimerEnd = timeStamp()

		local ProcessDurationMessage = ("Anim bake took :: " + (((BakeTimerEnd - BakeTimerStart) / 1000.0) as string) +  "s")

		if (DelayPrintArr == unsupplied) then
		(
			print(ProcessDurationMessage)
		)
		else
		(
			append DelayPrintArr ProcessDurationMessage
		)

		--Re-enable redraw after finishing!
		EnableSceneRedraw()
	)
)

--Copies transforms from one node hierarchy to another (Matched by name)
fn TransferPose ParentA: undefined ParentB:undefined NameBased:true Depth:-1 =
(
    local b_ref = GetChildren obj:ParentA
    local b_tar = GetChildren obj:ParentB

    StripPrefixes b_ref
	StripPrefixes b_tar

	SortToHierarchy &b_ref
	SortToHierarchy &b_tar

	local DepthCount = 0

	if (NameBased == true) then
	(
		--Apply by name
	    for tn in b_tar do
	    (
	        for rn in b_ref do
	        (
	            if (MatchPattern tn.name pattern:("*" + rn.name as string + "*") ignoreCase: true) do
	            (
	                tn.transform = rn.transform
	            )

	            if (Depth != -1) do
	            (
	            	Depth += 1

		            if (DepthCount >= Depth) do ( return() )
	            )
	        )
	    )
    )
    else
    (
    	--Apply by hierarchy index
		for i = 1 to b_tar.count do
	    (
	        for j = 1 to b_ref.count do
	        (
	        	local tn = b_tar[i]
	        	local rn = b_ref[j]

	            if (tn != undefined and rn != undefined) do
	            (
	                tn.transform = rn.transform
	            )

	            if (Depth != -1) do
	            (
	            	Depth += 1

		            if (DepthCount >= Depth) do ( return() )
	            )
	        )
	    )
    )
)

--Adding position constraint to node(obj) with parent(p) as target
fn AddPositionConstraint obj: p: weight:50 relative:false resetController:false =
(
	pc = Position_Constraint()
	c = pc.constraints
    c.appendTarget p weight

    pc.relative = relative

    if ((classOf(obj.position.controller) == position_list) and (resetController == false)) then
    (
    	obj.position.controller.available.controller = pc
    	return(pc)
    )
    else
    (
    	obj.position.controller = position_list()
    	obj.position.controller.available.controller = pc
		obj.position.controller.setActive 2

		return(obj.position.controller)
    )
)

--Adding orientation constraint to node(obj) with parent(p) as target
fn AddRotationConstraint obj: p: weight:50 relative:false resetController:false =
(
	oc = Orientation_Constraint()
	c = oc.constraints
    c.appendTarget p weight

    oc.relative = relative

    if ((classOf(obj.rotation.controller) == rotation_list) and (resetController == false)) then
    (
    	obj.rotation.controller.available.controller = oc
    	return(oc)
    )
    else
    (
    	local oldCnrtl = copy obj.rotation.controller

		obj.rotation.controller = rotation_list()
    	obj.rotation.controller.available.controller = oc
    	obj.rotation.controller.available.controller = oldCnrtl
    	obj.rotation.controller.delete 1
    	obj.rotation.controller.setActive 2
		return(obj.rotation.controller)
    )
)

--Adding LookAt constraint to node(obj) with parent(p) as target
fn AddLookatConstraint obj: p: weight:50 fwd:6 up:2 ups:1 upNode: relative:false resetController:false =
(
	lc = LookAt_Constraint()
	c = lc.constraints
    c.appendTarget p weight

    lc.relative = relative

    --Do this to control roll through target
    lc.pickUpNode = if (upNode == unsupplied) then undefined else p
    lc.upnode_world = (upNode == unsupplied)

    --#(5, 2, 4, 1)
	--("X-Positive", "Y-Positive", "Z-Positive", "X-Negative", "Y-Negative", "Z-Negative")
	case fwd of
    (
        1:
        (
            lc.target_axis = 0
            lc.target_axisFlip = false
        )

        2:
        (
            lc.target_axis = 1
            lc.target_axisFlip = false
        )

        3:
        (
        	lc.target_axis = 2
            lc.target_axisFlip = false
        )

        4:
        (
            lc.target_axis = 0
            lc.target_axisFlip = true
        )

        5:
        (
            lc.target_axis = 1
            lc.target_axisFlip = true
        )

        6:
        (
        	lc.target_axis = 2
            lc.target_axisFlip = true
        )
    )

    lc.StoUP_axis = ups
    lc.upnode_axis = up

    if ((classOf(obj.rotation.controller) == rotation_list) and (resetController == false)) then
    (
    	obj.rotation.controller.available.controller = lc
    	return(lc)
    )
    else
    (
    	local oldCnrtl = copy obj.rotation.controller

		obj.rotation.controller = rotation_list()
    	obj.rotation.controller.available.controller = lc
    	obj.rotation.controller.available.controller = oldCnrtl
    	obj.rotation.controller.delete 1
    	obj.rotation.controller.setActive 2
		return(obj.rotation.controller)
    )
)

--Setup parent constraint
fn AddParentConstraint tar: par: relative:false resetController:false =
(
	AddPositionConstraint obj:tar p:par relative:relative resetController:false
	AddRotationConstraint obj:tar p:par relative:relative resetController:false
)

fn OrientForwardAxis obj: fwd:1 =
(
	if (obj == unsupplied or obj == undefined) do (return())

	case fwd of
	(
		1: obj.rotation = eulerAngles 0 0 0   --X-Positive
		2: obj.rotation = eulerAngles 0 0 -90 --Y-Positive
		3: obj.rotation = eulerAngles 0 90 0  --Z-Positive
		4: obj.rotation = eulerAngles 0 0 180 --X-Negative
		5: obj.rotation = eulerAngles 0 0 90  --Y-Negative
		6: obj.rotation = eulerAngles 0 -90 0 --Z-Negative
	)
)
