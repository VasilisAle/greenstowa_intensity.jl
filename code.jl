using LasIO
using LazIO
using FileIO
using DataFrames
using ProgressMeter
using StaticArrays
using BenchmarkTools
using PointCloudRasterizers

#working datasets
workdir = dirname(@__FILE__)
const filenn_NL3_clipped = joinpath(workdir, "NL3_clipped_water_cropheight_pointformat3_classification_sorted.laz")
const filenn_NL1_3_splitted = joinpath(workdir, "3_splitted_sorted_pointformat3.laz")
const filenn_NL1_3_splitted_las = File{format"LAZ_"}(filenn_NL1_3_splitted)

#read specific LAS file
header, points = LazIO.load(filenn_NL1_3_splitted_las) #point cloud
n = length(points) #length

#output files
outputname = "_colored_points"
writefiles = joinpath(workdir, "3_splitted_sorted_pointformat3" * outputname * ".laz")

#read dataset
ds = LazIO.open(filenn_NL1_3_splitted) #dataset
df = DataFrame(ds) #dataframe, I can not retrieve right info ex. x coords without offset

#LazIO points
# pp = collect(ds)

function getpulse(points)
    prev_point = points[1]
    first_point = points[1]
    pulse =  Dict{Int,String}()
    n = 0
    for (i,p) in enumerate(points)
        inten = intensity(p)
        rn = return_number(p)
        nr = number_of_returns(p)
        dt = gps_time(first_point) - gps_time(prev_point)

        # global n = n + 1
        # println(rn," ",nr)

        if (nr > 1) &&  (rn == n + 1)
            if rn == 1
                pulse[i] = "firstpoint"
            elseif dt < 1e-7
                pulse[i] = "nextpoint"
            elseif rn == nr
                pulse[i] = "lastpoint"
                n = 0
            else
                n+=1
            end
            # println(" I added a point ", i)
        else
            n = 0
            pulse[i] ="unclassified"
            # println(" Point not added ", i)
        end
        prev_point = p
    end
    pulse
end

#write point cloud
function write_output(writefiles,ds,pulse)
    LazIO.write(writefiles, ds.header) do io
        for (i,p) in enumerate(ds) #I need to interate only to dataset, since it is Lazpoints
            allkeys = keys(pulse)
            if i in allkeys
                if pulse[i] == "unclassified"
                    p.classification = UInt(31)
                elseif pulse[i] == "firstpoint"
                    p.classification = UInt(3)
                elseif pulse[i] == "nextpoint"
                    p.classification = UInt(4)
                elseif pulse[i] == "lastpoint"
                    p.classification = UInt(5)
                end
                LazIO.writepoint(io,p)
            end
        end
    end
end

pulse = getpulse(points)
write_output(writefiles,ds,pulse)
