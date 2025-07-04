include("src/models/Vanilla_RNO/RNO.jl")
include("src/models/Vanilla_Transformer/Transformer.jl")
include("src/models/wavKAN_RNO/KAN_RNO.jl")
include("src/models/wavKAN_Transformer/KAN_Transformer.jl")

using CSV, DataFrames, Statistics, Printf, PlotlyJS, Flux, CUDA
using PlotlyJS: box, plot
using BSON: @load

log_locations = [
    "src/models/Vanilla_RNO/logs",
    "src/models/wavKAN_RNO/logs",
    "src/models/Vanilla_Transformer/logs",
    "src/models/wavKAN_Transformer/logs",
]

plot_names = [
    "MLP RNO",
    "wavKAN RNO",
    "MLP Transformer",
    "wavKAN Transformer",
]

model_file = [
    "src/models/Vanilla_RNO/logs/trained_models/model_5.bson",
    "src/models/wavKAN_RNO/logs/trained_models/model_1.bson", # This is the best one
    "src/models/Vanilla_Transformer/logs/trained_models/model_3.bson", 
    "src/models/wavKAN_Transformer/logs/trained_models/model_2.bson" # This is the best one
]

# Create array of param counts
# BSON has been acting up recently so these params are taken from previous experiments or modified scripts. They are correct.
# param_counts = [52, 39655, 4209205, 489562]
# param_counts = []
# for file_loc in model_file
#     @load file_loc model
#     push!(param_counts, sum(length, Flux.params(model)))
#     model = nothing
# end

num_repetitions = 5 

# Create an empty DataFrame to hold all results
results = DataFrame(Model = String[], train_loss = String[], test_loss = String[], BIC = String[], time = String[], param_count = Int64[])

box_plot_train = DataFrame(model = String[], value = Float64)
box_plot_test = DataFrame(model = String[], value = Float64)
box_plot_BIC = DataFrame(model = String[], value = Float64)
box_plot_time = DataFrame(model = String[], value = Float64)

for (idx, log_location) in enumerate(log_locations)
    train_loss, test_loss, BIC, time = [], [], [], []
    for i in 1:num_repetitions
        df = CSV.read("$log_location/repetition_$i.csv", DataFrame)
        # If test loss is NaN, skip this repetition
        if isnan(df[!,"Test Loss"][end])
            continue
        end
        push!(train_loss, df[!,"Train Loss"][end])
        push!(test_loss, df[!,"Test Loss"][end])
        push!(BIC, df[!,"BIC"][end])
        push!(time, df[!,"Time (s)"][end]/60)

        push!(box_plot_train, (model = plot_names[idx], value = df[!,"Train Loss"][end]), promote = true)
        push!(box_plot_test, (model = plot_names[idx], value = df[!,"Test Loss"][end]), promote = true)
        push!(box_plot_BIC, (model = plot_names[idx], value = df[!,"BIC"][end]), promote = true)
        push!(box_plot_time, (model = plot_names[idx], value = df[!,"Time (s)"][end]/3600), promote = true)
    end

    train_loss_mean = mean(train_loss)
    train_loss_std = std(train_loss)
    test_loss_mean = mean(test_loss)
    test_loss_std = std(test_loss)
    BIC_mean = mean(BIC)
    BIC_std = std(BIC)
    time_mean = mean(time)
    time_std = std(time)

    push!(results, (
        Model = plot_names[idx],
        train_loss = @sprintf("%.2g ± %.2g", train_loss_mean, train_loss_std),
        test_loss = @sprintf("%.2g ± %.2g", test_loss_mean, test_loss_std),
        BIC = @sprintf("%.2g ± %.2g", BIC_mean, BIC_std),
        time = @sprintf("%.2g ± %.2g", time_mean, time_std),
        param_count = param_counts[idx]
    ))
end

headerColor = "grey"
rowEvenColor = "lightgrey"
rowOddColor = "white"

table_plot = plot(
    table(
        header = attr(values = ["Model", "Train Loss", "Test Loss", "BIC", "Time (mins)", "Param Count"],
        align="center",
        line_color="darkslategray",
        fill_color=headerColor,
        font=attr(family="Computer Modern", color="white", size=13)),
        cells = attr(values = [plot_names, results.train_loss, results.test_loss, results.BIC, results.time, results.param_count],
        line_color="darkslategray",
        fill_color=[ [rowOddColor,rowEvenColor,rowOddColor,rowEvenColor, rowOddColor]],
        align = "center",
        font = attr(family="Computer Modern", size=12, color="black")),
    ),
    Layout(
        autosize=true,
        title = attr(text = "Loss and BIC for Different Models", x = 0.5),
        font = attr(family="Computer Modern", size=12, color="black"),
        margin = attr(b = 0, t=200, l=5, r=5),
        scale=5,
    )
)

savefig(table_plot, "figures/loss_table.png")

function box_data(df, name)
    data = []
    for (idx, plot_name) in enumerate(plot_names)
        vals = Float64.(df[df.model .== plot_name, :value])
        trace = box(;y=vals, name=plot_name)
        push!(data, trace)
    end
    data = [data...]
    boxplot = plot(data, Layout(;title=name, xaxis_title="Model", yaxis_title=name))
    
    savefig(boxplot, "figures/$(name).png")
end


box_data(box_plot_train, "Train Loss")
box_data(box_plot_test, "Test Loss")
box_data(box_plot_BIC, "BIC")
box_data(box_plot_time, "Time (mins)")





