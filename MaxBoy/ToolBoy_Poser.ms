
(
rollout Poser "Poser" width:200 height: 250
(
	include "$userScripts\MaxBoy\MaxBoy_Functions.ms"
	global Packages = #(); --Package array
	global Poses = #();
	global filePath;

	struct PoseContainer (poseName, posePackages)
	struct PosePackage (ob, na, tr, pc)

	group "Pose Tools"
	(
		button CopyPose  "Copy Pose"  align:#center
		button PastePose "Paste Pose" align:#center

		combobox ui_poses "Poses" height:6
	)

	fn fn_SortByParentCount pack_a pack_b =
	(
		local d = (pack_a.pc) - (pack_b.pc)

		case of
		(
			(d < 0.): -1
			(d > 0.): 1
			default: 0
		)
	)

	--Save pose to .poseboi file
	fn SavePose poseName =
	(
		gc()

		local sFile = undefined

		if (doesFileExist filePath == false) then
		(
			sFile = createFile filePath
			--print("Made new anim setup file!")
		)
		else
		(
			sFile = openFile filePath mode:"a"
			--print("Wrote to existing anim setup file!")
		)

		if (sFile != undefined) do
		(
			--local i = 0

			format ("pose_" + (poseName as string) + "\n") to:sFile

			for p in Packages do
			(
				--i += 1

				--print("Saved sequence << " + s.s_Name)
				--format ("[Pose_" + (i as string) + "]" + "\n") to:sFile

				format (p.na as string + "\n") to:sFile
				format (p.tr as string + "\n") to:sFile
				format (p.pc as string + "\n") to:sFile
				--format ("[Pose_END]\n\n") to:sFile
			)

			format ("_x\n\n") to:sFile

			close sFile

			--print("[ Saved sequence settings to file ]")
		)
	)

	--Load from .poseboi file
	fn LoadPoses =
	(
		gc()
		free Poses
		free Packages

		if (doesFileExist filePath == false) do
		(
			print("No file to load from @ " + filePath as string)
			return()
		)

		local oFile = openFile filePath mode:"r"
		--skipToNextLine oFile
		--skipToNextLine oFile

		if (oFile != undefined) then
		(
			do
			(
				do
				(
					local searchAttempt = skipToString oFile "pose_"

					if (searchAttempt != undefined) do
					(
						local newPoseContainerName = (readLine oFile as string)

						--Prepare new pose container
						local newPoseContainer = PoseContainer poseName: newPoseContainerName posePackages:#()

						--Position reading starting location in file
						--skipToNextLine oFile

						while(readChars oFile 2 != "_x") do
						(
							--print(filePos oFile)
							local r_name = (readLine oFile as string)
							--print(filePos oFile)
							local r_transform = (readValue oFile as Matrix3)
							--print(filePos oFile)
							local r_pc = (readValue oFile as integer)

							local loadedPose = PosePackage ob:undefined na:r_name tr:r_transform pc:r_pc

							append newPoseContainer.posePackages loadedPose
						)

						print("Loaded [ " + (newPoseContainer.posePackages.count as string) + " ] packages for pose >> " + (newPoseContainer.poseName as string))

						append Poses newPoseContainer
					)
				) while ( searchAttempt != undefined )
			) while (eof == false)
			--while (searchResult != undefined)

			close oFile

			print("[ Loaded poses from file ]")
		)
		else
		(
			print("Unable to open file!")
		)

		if (Poses != undefined) do
		(
			if (Poses.count > 0) do
			(
				local poseNameArray = #()

				for p in Poses do
				(
					append poseNameArray p.poseName
				)

				ui_poses.items = poseNameArray
			)
		)
	)

	on Poser open do
	(
		local srcLocation = getScriptLocation (getThisScriptFilename() as string) "ToolBoy_Poser"
		makeDir (srcLocation + "\\Poser\\")

		local relativePath = (srcLocation + "\\Poser\\" + "PosesMain_Test.poseboi")
		filePath = convertToPath relativePath

		LoadPoses()

		/*Capture thumbnail
		gc()

		local srcLocation = getScriptLocation (getThisScriptFilename() as string) "ToolBoy_Poser"
		makeDir (srcLocation + "\\Poser\\")

		local relativePath = (srcLocation + "\\Poser\\" + "TestThumb.bmp")
		filePath = convertToPath relativePath

		--preview_name = (getDir #preview)+"/quickpreview.jpg"
		v_size = getViewSize()
		v_thumb = gw.getViewportDib()
		v_thumb.fileName = filePath
		save v_thumb

		thumbnail = bitmaptexture bitmap:v_thumb
		thumbnail.fileName = filePath
		thumbnail.apply = true

		if (v_size.x > v_size.y) then
		(
			local factor = (v_size.x / v_size.y)

			thumbnail.cropPlace = 0
			thumbnail.clipu = factor * -0.1

			thumbnail.cropPlace = 0
			--thumbnail.clipw = (v_size.y / v_size.x)
		)
		else
		(
			local factor = (v_size.y / v_size.x)

			thumbnail.cropPlace = 0
			thumbnail.clipv = factor * 0.1

			thumbnail.cropPlace = 0
			--thumbnail.clipw = (v_size.x / v_size.y)
		)

		renderMap thumbnail size:[512, 512] filter:on display:on
		--renderMap thumbnail size:[v_size.x / 3,v_size.y / 3] filter:on display:on
		*/
	)

	on CopyPose pressed do
	(
		--Clear stored packages
		free Packages

		--Garbage collect just in case
		gc()

		--Stop operation if selection is empty
		if selection.count == 0 do
		(
			print("Selection empty, stopping!")
			return()
		)

		--Start operation
		print("Copying pose...")

		for obj in selection do
		(
			if isValidNode(obj) do
			(
				at time sliderTime
				(
					local poseTransform = in coordsys world obj.transform
				)

				local newPackage = PosePackage ob:obj na:obj.name tr:poseTransform pc:0

				append Packages newPackage
			)
		)

		for pack in Packages do
		(
			local p = pack.ob

			while (p != undefined) do
			(
				p = p.parent
				pack.pc += 1
			)
			--print("Parent count { " + (pack.ob.name as string) + " } >> " + (pack.pc as string))
		)

		qsort Packages fn_SortByParentCount
		--print(Packages)

		local poseName = ("Pose_" + (ui_poses.items.count as string))

		SavePose(poseName)
		LoadPoses()
	)

	on PastePose pressed do
	(
		if (Packages.count == 0) do
		(
			print("No stored pose packages!")
			return()
		)

		print("Pasting pose...")

		--print("Packages {")
		--print(Packages)

		for pack in Packages do
		(
			--Apply stored pose transform to object
			at time sliderTime
			(
				in coordsys world
				animate on

				local tryFindNode = getNodeByName(pack.na)

				if (isValidNode(tryFindNode)) then
				(
					tryFindNode.transform = pack.tr
				)
				else
				(
					print("Couldn't find node: " + pack.na)
				)
			)
		)
	)
)

createDialog Poser
)
