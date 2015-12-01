json.swagger '2.0'
json.info do
  json.description @doc[:docs][:info]
  json.title @doc[:docs][:name]
  json.version Apipie.configuration.default_version
end
json.host(request.host)
json.basePath(Apipie.configuration.api_base_url[Apipie.configuration.default_version])
json.schemes Rails.env.production? ? ['https'] : ['http']

def normalize_params(param, parameter_names)
  {
    in: parameter_names.include?(param[:name]) ? :path : :formData,
    name: param[:full_name],
    description: param[:description].presence || param[:name],
    type: params[:expected_type] || 'string'
  }.merge(param.slice(:required, :params))
end

tags = []
paths = @doc[:docs][:resources].each_with_object({}) do |(resource_name, resource), paths|
  tags << {
    name: resource[:name],
    description: resource[:full_description].presence || resource[:short_description],
    externalDocs: {
      url: resource[:doc_url]
    }
  }
  resource[:methods].each do |method|
  formats = method[:formats].map { |format| Mime::Type.lookup_by_extension(format).to_s }.uniq
  parameter_names = Set.new
  method[:apis].each do |api|
    path = api[:api_url]
    path.gsub!(/\/:(?<name>[^\/]+)/) do |match|
      param_name = match[2..-1]
      parameter_names << param_name
      "/{#{param_name}}"
    end
    http_method = api[:http_method].underscore
    paths[path] ||= {}
    error_responses = method[:errors].each_with_object({}) do |error, responses|
      responses[error[:code].to_s] = error.slice(:description)
    end
    parameters = method[:params].map do |param|
      normalize_params(param, parameter_names)
    end
    parameters.each do |parameter|
      if parameter[:params]
        parameters += parameter.delete(:params).map do |param|
          normalize_params(param, parameter_names)
        end
      end
    end while parameters.any? { |parameter| parameter[:params] }
    paths[path][http_method] = {
      tags: [ resource[:name] ],
      summary: api[:short_description],
      responses: error_responses,
      consumes: formats,
      produces: formats
    }
    paths[path][http_method][:parameters] = parameters if parameters.any?
    paths[path][http_method]
  end; end
end
json.tags(tags)
json.paths(paths)
