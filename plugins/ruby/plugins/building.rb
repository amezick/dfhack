module DFHack

# allocate a new building object
def self.building_alloc(type, subtype=-1, custom=-1)
	cls = rtti_n2c[BuildingType::Classname[type].to_sym]
	raise "invalid building type #{type.inspect}" if not cls
	bld = cls.cpp_new
	bld.race = ui.race_id
	bld.setSubtype(subtype) if subtype != -1
	bld.setCustomType(custom) if custom != -1
	case type
	when :Furnace; bld.melt_remainder[world.raws.inorganics.length] = 0
	when :Coffin; bld.initBurialFlags
	when :Trap; bld.unk_cc = 500 if bld.trap_type == :PressurePlate
	end
	bld
end

# used by building_setsize
def self.building_check_bridge_support(bld)
	x1 = bld.x1-1
	x2 = bld.x2+1
	y1 = bld.y1-1
	y2 = bld.y2+1
	z = bld.z
	(x1..x2).each { |x|
		(y1..y2).each { |y|
			next if ((x == x1 or x == x2) and
				 (y == y1 or y == y2))
			if mb = map_block_at(x, y, z) and tile = mb.tiletype[x%16][y%16] and TiletypeShape::BasicShape[Tiletype::Shape[tile]] == :Open
				bld.gate_flags.has_support = true
				return
			end
		}
	}
	bld.gate_flags.has_support = false
end

# sets x2/centerx/y2/centery from x1/y1/bldtype
# x2/y2 preserved for :FarmPlot etc
def self.building_setsize(bld)
	bld.x2 = bld.x1 if bld.x1 > bld.x2
	bld.y2 = bld.y1 if bld.y1 > bld.y2
	case bld.getType
	when :Bridge
		bld.centerx = bld.x1 + (bld.x2+1-bld.x1)/2
		bld.centery = bld.y1 + (bld.y2+1-bld.y1)/2
		building_check_bridge_support(bld)
	when :FarmPlot, :RoadDirt, :RoadPaved, :Stockpile, :Civzone
		bld.centerx = bld.x1 + (bld.x2+1-bld.x1)/2
		bld.centery = bld.y1 + (bld.y2+1-bld.y1)/2
	when :TradeDepot, :Shop
		bld.x2 = bld.x1+4
		bld.y2 = bld.y1+4
		bld.centerx = bld.x1+2
		bld.centery = bld.y1+2
	when :SiegeEngine, :Windmill, :Wagon
		bld.x2 = bld.x1+2
		bld.y2 = bld.y1+2
		bld.centerx = bld.x1+1
		bld.centery = bld.y1+1
	when :AxleHorizontal
		if bld.is_vertical == 1
			bld.x2 = bld.centerx = bld.x1
			bld.centery = bld.y1 + (bld.y2+1-bld.y1)/2
		else
			bld.centerx = bld.x1 + (bld.x2+1-bld.x1)/2
			bld.y2 = bld.centery = bld.y1
		end
	when :WaterWheel
		if bld.is_vertical == 1
			bld.x2 = bld.centerx = bld.x1
			bld.y2 = bld.y1+2
			bld.centery = bld.y1+1
		else
			bld.x2 = bld.x1+2
			bld.centerx = bld.x1+1
			bld.y2 = bld.centery = bld.y1
		end
	when :Workshop, :Furnace
		# Furnace = Custom or default case only
		case bld.type
		when :Quern, :Millstone, :Tool
			bld.x2 = bld.centerx = bld.x1
			bld.y2 = bld.centery = bld.y1
		when :Siege, :Kennels
			bld.x2 = bld.x1+4
			bld.y2 = bld.y1+4
			bld.centerx = bld.x1+2
			bld.centery = bld.y1+2
		when :Custom
			if bdef = world.raws.buildings.all.binsearch(bld.getCustomType)
				bld.x2 = bld.x1 + bdef.dim_x - 1
				bld.y2 = bld.y1 + bdef.dim_y - 1
				bld.centerx = bld.x1 + bdef.workloc_x
				bld.centery = bld.y1 + bdef.workloc_y
			end
		else
			bld.x2 = bld.x1+2
			bld.y2 = bld.y1+2
			bld.centerx = bld.x1+1
			bld.centery = bld.y1+1
		end
	when :ScrewPump
		case bld.direction
		when :FromEast
			bld.x2 = bld.centerx = bld.x1+1
			bld.y2 = bld.centery = bld.y1
		when :FromSouth
			bld.x2 = bld.centerx = bld.x1
			bld.y2 = bld.centery = bld.y1+1
		when :FromWest
			bld.x2 = bld.x1+1
			bld.y2 = bld.centery = bld.y1
			bld.centerx = bld.x1
		else
			bld.x2 = bld.x1+1
			bld.y2 = bld.centery = bld.y1
			bld.centerx = bld.x1
		end
	when :Well
		bld.bucket_z = bld.z
		bld.x2 = bld.centerx = bld.x1
		bld.y2 = bld.centery = bld.y1
	when :Construction
		bld.x2 = bld.centerx = bld.x1
		bld.y2 = bld.centery = bld.y1
		bld.setMaterialAmount(1)
		return
	else
		bld.x2 = bld.centerx = bld.x1
		bld.y2 = bld.centery = bld.y1
	end
	bld.setMaterialAmount((bld.x2-bld.x1+1)*(bld.y2-bld.y1+1)/4+1)
end

# set building at position, with optional width/height
def self.building_position(bld, pos, w=nil, h=nil)
	bld.x1 = pos.x
	bld.y1 = pos.y
	bld.z  = pos.z
	bld.x2 = bld.x1+w-1 if w
	bld.y2 = bld.y1+h-1 if h
	building_setsize(bld)
end

# set map occupancy/stockpile/etc for a building
def self.building_setoccupancy(bld)
	stockpile = (bld.getType == :Stockpile)
	complete = (bld.getBuildStage >= bld.getMaxBuildStage)
	extents = (bld.room.extents and bld.isExtentShaped)

	z = bld.z
	(bld.x1..bld.x2).each { |x|
		(bld.y1..bld.y2).each { |y|
			next if !extents or bld.room.extents[bld.room.width*(y-bld.room.y)+(x-bld.room.x)] == 0
			next if not mb = map_block_at(x, y, z)
			des = mb.designation[x%16][y%16]
			des.pile = stockpile
			des.dig = :No
			if complete
				bld.updateOccupancy(x, y)
			else
				mb.occupancy[x%16][y%16].building = :Planned
			end
		}
	}
end

# link bld into other rooms if it is inside their extents
def self.building_linkrooms(bld)
	didstuff = false
	world.buildings.other[:ANY_FREE].each { |ob|
		next if !ob.is_room or ob.z != bld.z
		next if !ob.room.extents or !ob.isExtentShaped or ob.room.extents[ob.room.width*(bld.y1-ob.room.y)+(bld.x1-ob.room.x)] == 0
		didstuff = true
		ob.children << bld
		bld.parents << ob
	}
	ui.equipment.update.buildings = true if didstuff
end

# link the building into the world, set map data, link rooms, bld.id
def self.building_link(bld)
	bld.id = df.building_next_id
	df.building_next_id += 1

	world.buildings.all << bld
	bld.categorize(true)
	building_setoccupancy(bld) if bld.isSettingOccupancy
	building_linkrooms(bld)
end

# set a design for the building
def self.building_createdesign(bld, rough=true)
	job = bld.jobs[0]
	job.mat_type = bld.mat_type
	job.mat_index = bld.mat_index
	if bld.needsDesign
		bld.design = BuildingDesign.cpp_new
		bld.design.flags.rough = rough
	end
end

# creates a job to build bld, return it
def self.building_linkforconstruct(bld)
	building_link bld
	ref = GeneralRefBuildingHolderst.cpp_new
	ref.building_id = bld.id
	job = Job.cpp_new
	job.job_type = :ConstructBuilding
	job.pos = [bld.centerx, bld.centery, bld.z]
	job.references << ref
	bld.jobs << job
	job_link job
	job
end

# construct a building with items or JobItems
def self.building_construct(bld, items)
	job = building_linkforconstruct(bld)
	rough = false
	items.each { |item|
		if items.kind_of?(JobItem)
			item.quantity = (bld.x2-bld.x1+1)*(bld.y2-bld.y1+1)/4+1 if item.quantity < 0
			job.job_items << item
		else
			job_attachitem(job, item, :Hauled)
		end
		rough = true if item.getType == :BOULDER
		bld.mat_type = item.getMaterial if bld.mat_type == -1
		bld.mat_index = item.getMaterialIndex if bld.mat_index == -1
	}
	building_createdesign(bld, rough)
end

# creates a job to deconstruct the building
def self.building_deconstruct(bld)
	job = Job.cpp_new
	refbuildingholder = GeneralRefBuildingHolderst.cpp_new
	job.job_type = :DestroyBuilding
	refbuildingholder.building_id = building.id
	job.references << refbuildingholder
	building.jobs << job
	job_link job
	job
end

# exemple usage
def self.buildbed(pos=cursor)
	suspend {
		raise 'where to ?' if pos.x < 0

		item = world.items.all.find { |i|
			i.kind_of?(ItemBedst) and
			i.itemrefs.empty? and
			!i.flags.in_job
		}
		raise 'no free bed, build more !' if not item

		bld = building_alloc(:Bed)
		building_position(bld, pos)
		building_construct(bld, [item])
	}
end
end
