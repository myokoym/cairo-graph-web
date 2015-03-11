require "sinatra"
require "haml"
require "cairo/graph"

FORMATS = {
  "png" => "PNG",
  "pdf" => "PDF",
}

MAX_ROWS = 6

get "/" do
  @formats = FORMATS
  @max_rows = MAX_ROWS
  @params ||= {}
  set_default_params(@params)
  haml :index
end

post "/" do
  @formats = FORMATS
  @max_rows = MAX_ROWS
  begin
    @download_url = output_downloadable_file
  rescue => e
    return "Error: #{e}"
  end

  @params = params
  haml :index
end

helpers do
  def set_default_params(params)
    [
      [[253, 503,  84,  687, 859,  361, 110,  403], "Senna"],
      [[588, 766, 485, 1039, 862, 1028, 155,  235], "Groonga"],
      [[504, 192, 610,  541, 469,  192, 194, 1072], "Rroonga"],
      [[ 31, 694,  80,    3, 762,   85, 620, 1078], "Mroonga"],
      [[422, 288, 376, 1162, 153,  218, 303,  638], "Nroonga"],
      [[264, 106, 167,  586, 204,  597, 831, 1111], "Droonga"],
    ].each_with_index do |data_label, i|
      data, label = *data_label
      params["data#{i}"] = data.join(",")
      params["label#{i}"] = label
    end
    params[:columns] = [*1..8].collect do |i|
      "5/#{i}"
    end.join(",")
    params[:width] = 960
    params[:height] = 480
    params[:title] = "Graph by rcairo"
    params[:unit] = "(Unit)"
  end

  def filename
    return @filename if @filename
    @filename = params[:filename]
    @filename = Time.now.strftime("%Y%m%d%H%M%S") if @filename.empty?
    @filename << ".#{format}" unless /.#{format}\z/ =~ @filename
    @filename
  end

  def font
    @font ||= params[:font]
  end

  def format
    @format ||= params[:format]
  end

  def vertical?
    params[:direction] == "vertical"
  end

  def output_downloadable_file
    today = Time.now.strftime("%Y%m%d")
    base_dir = "public/images/#{today}"
    FileUtils.mkdir_p(base_dir)
    output_path = File.join(base_dir, filename)

    graph = create_graph
    render_graph(graph, output_path)

    "#{base_url}/#{base_dir.gsub(/\Apublic\//, "")}/#{filename}"
  end

  def create_graph
    rows = MAX_ROWS.times.collect do |i|
      [params["data#{i}"].split(/,/).collect(&:to_i), params["label#{i}"]]
    end

    rows.reject! do |row|
      row[1].empty?
    end

    columns = params[:columns].split(/,/)

    width = params[:width].to_i
    height = params[:height].to_i

    graph = Cairo::Graph.new(:width => width, :height => height)
    graph.title = params[:title] || "Graph by rcairo"
    graph.unit_name = "(Unit)"
    graph.columns = columns
    #graph.grid_max = 1200
    #graph.grid_step = 200
    graph.font = "VL Gothic"
    rows.each do |row_with_name|
      row, name = *row_with_name
      graph.add(row, name)
    end
    graph
  end

  def render_graph(graph, output_path)
    width = graph.width
    height = graph.height
    case format
    when "png"
      Cairo::ImageSurface.new(:argb32, width, height) do |surface|
        Cairo::Context.new(surface) do |context|
          context.show_graph(graph)
        end
        surface.write_to_png(output_path)
      end
    when "pdf"
      Cairo::PDFSurface.new(output_path, width, height) do |surface|
        Cairo::Context.new(surface) do |context|
          context.show_graph(graph)
          context.show_page
        end
      end
    end
  end

  def base_url
    parts_of_url = {
      :scheme => request.scheme,
      :host   => request.host,
      :port   => request.port,
      :path   => request.script_name,
    }
    URI::Generic.build(parts_of_url).to_s.gsub(/(#{request.scheme}:\/\/#{request.host}):80/, '\1')
  end
end
