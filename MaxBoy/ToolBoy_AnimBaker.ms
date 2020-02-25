
(
rollout Baker "AnimBaker v8" width:200 height: 256 (

	global transformList = #();
	global nodeList = #();

	group "Ranges"
	(
		spinner range_start "Start frame " pos:[26,28] width:112 height:16 range:[-10000,10000,normTime 0] type:#integer
		spinner range_end   "End frame  " pos:[26,50] width:112 height:16 range:[-10000,10000,normTime 1] type:#integer

		button GetStart "<" pos:[142,28] width:20 height:16 toolTip:"Set start frame to current frame"
		button GetEnd   "<" pos:[142,50] width:20 height:16 toolTip:"Set end frame to current frame"

		button GetStartRange "<<" pos:[166,28] width:20 height:16 toolTip:"Set start frame to current range start frame"
		button GetEndRange   "<<" pos:[166,50] width:20 height:16 toolTip:"Set start frame to current range end frame"
	)

	group ""
	(
		button BakeObject "[  BAKE  ]" width:175 align:#center
		pickbutton refPick "<< Pick Reference >>" width:175 align:#center

		checkbox bakeToDummy "  -  Bake to dummy" toolTip:"Bake animation data down to a separate dummy object"
		checkbox useRef "  -  Use reference" toolTip:"Lock object to reference"
		checkbox useStartRef "  -  Start as ref" toolTip:"Use starting frame as reference and lock object to it. (Good for IK handles)"
		checkbox ReverseAnimation "  -  Reverse" checked:false
		checkbox KeepControllers "  -  Keep controllers" checked:false
	)

	/*
	group "Pose Tools"
	(
		button CopyPose  "Copy Pose"  align:#center
		button PastePose "Paste Pose" align:#center
	)
	*/

	on refPick picked obj do
	(
		if (obj != undefined) do
		(
			 refPick.text = ("Ref >> { " + obj.name + " }")
		)
	)

	on refPick rightclick do
	(
		refPick.object = undefined
		refPick.text = ("<< Pick Reference >>")
	)

	on GetStart pressed do
	(
		range_start.value = ( sliderTime )
	)

	on GetEnd pressed do
	(
		range_end.value = ( sliderTime )
	)

	on GetStartRange pressed do
	(
		range_start.value = ( normTime 0 as integer ) / ticksperframe
	)

	on GetEndRange pressed do
	(
		range_end.value = ( normTime 1 as integer ) / ticksperframe
	)

	on CopyPose pressed do
	(
		--clearListener()

		if selection.count != undefined then
		(
			if ((nodeList != undefined) or (transformList != undefined)) do
			(
				free nodeList
				free transformList
			)

			print("Copying object transforms...")

			with animate on
			(
				for obj in selection do
				(
					at time slidertime

					append nodeList obj
					append transformList obj.transform
				)
			)

			set animate off
			--print(transformList)
	    )
	)

	on PastePose pressed do
	(
		select nodeList

		if (transformList != undefined) then
		(
			for i=1 to selection.count do
			(
				--print("pass: " + i as string)

				if matchPattern nodeList[i].name pattern:(selection[i].name) == true then
				(
					--print("Transferring object transforms...")
					with animate on
					(
						at time slidertime
						selection[i].transform = transformList[i]
					)

					continue
				)
				else
				(
					print("missed!")
					continue
				)
			)
		)
		else
		(
			print("Copy something first!")
		)
	)

	--Bake down object process
	on BakeObject pressed do (
		--checkGot = selection
		--pleb = $selection[1]
		--ref = $selection[2]

		if $ != undefined then
		(
			with redraw off
			(
			try
			(
				disableSceneRedraw()

				free selectionArray
				selectionArray = selection
				tempTransformArray = #()--Store temp transform objects into array

				global tf = #()--Transform array

				local collectedFirstFrameData = false
				local StartFrameTransforms = #()

				--Initiate copying pass index var
				local copyPass = 0

				for t = range_start.value to range_end.value do
				(
					copyPass += 1

					local ObjectData = #()
					local ObjectKeys = #()

					for i = 1 to selectionArray.count do
					(
						obj = selectionArray[i]

						if obj != undefined then
						(
							if (collectedFirstFrameData == false) do
							(
								if (useStartRef.state == true) do
								(
									--Collect first frame transform data and store into array
									at time range_start.value
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
							print("Undefined object, ignoring.")
						)
					)

					--After first pass of processing, set to not collect further data
					collectedFirstFrameData = true
				)

				--Are we baking to dummy or no? Reset controllers or make dummies.
				if (bakeToDummy.state == false) then
				(
					--Fix object controllers--
					for obj in selectionArray do
					(
						local testResult = true
						--Make sure you're checking a controller and not Matrix3
						try (classOf obj.transform.controller) catch (testResult = false) --Throws error if it's a bad cast

						--print("TestResult: " + testResult as string)

						--Did we pass the test?
						if (testResult == true) do
						(
							--Only do reset operation if controller is of type PRS (Position/Rotation/Scale)
							if (classOf obj.transform.controller == PRS) do
							(
								if (KeepControllers.state == false) do
								(
									obj.transform.controller = prs()
									obj.position.controller = position_XYZ() --Do this steps to make sure controllers get reset fully
									obj.rotation.controller = Euler_XYZ() --Do this steps to make sure controllers get reset fully
								)
							)
						)
					)
				)
				else
				(
					local bakeDummies = #()--Store temp transform objects into array
					animate off
					--Make dummy objects to apply baked data to--
					for obj in selectionArray do
					(
						local bd = Point name:("baked_" + obj.name as string) size:10
						bd.transform.controller = prs()
						bd.position.controller = position_XYZ()
						bd.rotation.controller = Euler_XYZ()

						bd.transform = obj.transform

						append bakeDummies bd
					)

					--Transfer temp array of new bake data dummies over to become selection array
					free selectionArray
					selectionArray = bakeDummies
				)

				--Initiate pasting pass index var
				local pastePass = 0

				local virtualStartFrame = range_start.value
				local virtualEndFrame = range_end.value
				local stepBasis = 1

				--Flip start/ end frames depending on if we're reversing or not
				if (ReverseAnimation.state == true) do
				(
					virtualStartFrame = range_end.value
					virtualEndFrame = range_start.value
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

					for i = 1 to selectionArray.count do
					(
						animate off

						in coordsys world
						(
							local getPackage = tf[pastePass]
							local getPackageObject = getPackage[1][i]
							local getPackageFrames = getPackage[2][i]

							--Get object based on name if we're baking to a dummy
							if (bakeToDummy.state == true) do
 								getPackageObject = getNodeByName("baked_" + getPackage[1][i].name)

							--print(("Selection: " + getPackageObject as string) + (" at frame: " + t as string))

							--Apply fetched transform to object
							at time t
							(
								animate on

								if (useStartRef.state == true) then
								(
									getPackageObject.transform = StartFrameTransforms[i]
								)
								else if (useRef.state == true) then
								(
									getPackageObject.transform = refPick.object.transform
								)
								else
								(
									getPackageObject.transform = getPackageFrames
								)

								--addNewKey getPackageObject t
							)
						)
					)
				)

				free bakeDummies
				free tempTransformArray
				free selectionArray
				free ObjectData
				free ObjectKeys
			)
			catch
			(
				enableSceneRedraw()
				messagebox("Something messed up!") title:"Error!"
			)
			)

			--Reset animation sate and allow redraw
			enableSceneRedraw()
	    )
		else
		(
			messagebox("Select something first!") title:"Ay!"
		)
	)
)
createDialog Baker
)
