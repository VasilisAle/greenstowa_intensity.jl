using LasIO
using LazIO
using FileIO
using DataFrames
using ProgressMeter
using StaticArrays
using BenchmarkTools
using PointCloudRasterizers
using NearestNeighbors #use it for spatial search


#get the pulse
function classify(points)
    prev_point = points[1]
    pulse =  Dict{Int,String}() #dictionary with indexes and tags
    n = 0
    for (i,p) in enumerate(points)
        point = p
        inten = intensity(p)
        rn = return_number(p)
        nr = number_of_returns(p)
        dt = gps_time(point) - gps_time(prev_point)
        #rn = return number, nr = number_of_returns
        if (rn == n + 1) && (nr > 1)
            if rn == 1
                pulse[i] = "firstpoint"
            elseif rn < nr && dt < 1e-7
                pulse[i] = "nextpoint"
            elseif rn == nr && dt < 1e-7
                pulse[i] = "lastpoint"
            end
            if nr == rn
                n = 0
            end
        elseif nr == 1 && rn == 1
            pulse[i] = "firstpoint"
            n = 0
        else
            pulse[i] ="unclassified"
            n = 0
        end
        n+=1
        prev_point = p
    end
    pulse
end

#write point cloud
function write_output(writefiles,ds, pulse)
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

##MAIN##
#working with 4 different datasets
workdir = dirname(@__FILE__)
# dataname_1 = "NL3_clipped_water_cropheight_pointformat3_classification_sorted"
# dataname_2 = "3_splitted_sorted_pointformat3"
# dataname_3 = "12_splitted_sorted_pointformat3_clipZ"
dataname_4 = "14_splitted_sorted_pointformat3_clipZ"

const filenn_NL1 = joinpath(workdir,dataname_4 * ".laz")
const filenn_NL1_las = File{format"LAZ_"}(filenn_NL1)

#read specific LAS file
header, points = LazIO.load(filenn_NL1_las) #point cloud as LAS format
n = length(points) #length

#output files
outputname = "_classified"
writefiles = joinpath(workdir, dataname_4 * outputname * ".laz")

#read dataset
ds = LazIO.open(filenn_NL1)#dataset

#pulse
classified = classify(points)

#write output
write_output(writefiles,ds,classified)
