
(
--Include function lib
include "$userscripts\maxboy\maxboy_functions.ms"

rollout Baker "AnimBaker v10.1" width:200 height: 240 (

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

		dropdownlist bakeMethod "Method" items:#("Regular", "Reference", "Dummy", "Start") toolTip:"Choose which bake method to use \n\n Regular :: Bakes all keys, resets controller \n Reference :: Align to reference node \n Dummy :: Bake to new dummy node \n Start :: Use start frame as anchor point"

		--checkbox useRef "  -  Use reference" toolTip:"Lock object to reference" checked:true
		--checkbox bakeToDummy "  -  Bake to dummy" toolTip:"Bake animation data down to a separate dummy object"
		--checkbox useStartRef "  -  Start as ref" toolTip:"Use starting frame as reference and lock object to it. (Good for IK handles)"
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
	on BakeObject pressed do
	(
		--checkGot = selection
		--pleb = $selection[1]
		--ref = $selection[2]

		if (selection.count != 0) then
		(
			for o in selection do
			(
				try
				(
					--Test if we can fetch something form a CAT specific controller handle
					local fetchController = o.TMcontroller

					messagebox("This doesn't support CAT controllers yet!") title:"Error!"
					return()
				)
				catch
				(
					--Whatever
				)
			)

			BakeKeys collection:(selection as array) rs:(range_start.value) re:(range_end.value) method:(bakeMethod.selection) rev:(ReverseAnimation.state) ref:(refPick.object) keepController:(KeepControllers.state)

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
