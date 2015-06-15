require "json"
class ProjectForm
	def initialize(json_project)
		@id = json_project["id"]
		@name=json_project["name"].to_s
		@identifier=json_project["identifier"].to_s
		@description=json_project["description"].to_s
		@updated_on=Time.parse(json_project["updated_on"]).strftime('%Y-%m-%d')
	end

	def id
		@id
	end
	
	def name
		@name
	end

	def identifier
		@identifier
	end

	def description
		@description
	end

	def updated_on
		@updated_on
	end
end