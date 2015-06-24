require "json"
class IssueForm
	def initialize(json_issue)
		@id = json_issue["id"]
		@status_id =json_issue["status"]["name"].to_s
		@subject = json_issue["subject"].to_s
		@priority_id = json_issue["priority"]["name"]
		@tracker_id = json_issue["tracker"]["name"]
		@start_date = json_issue["start_date"].to_s
		@due_date = json_issue["due_date"].to_s
		@done_ratio = json_issue["done_ratio"].to_i
		@description = json_issue["description"].to_s
		@custom_fields_json = json_issue["custom_fields"]
		@custom_fields = []
		
		begin
			@fixed_version = json_issue["fixed_version"]["id"]
		rescue
		end

		begin
			@parent = json_issue["parent"]["id"]
		rescue
			@parent = nil
		end

		begin
			@category = json_issue["category"]["name"]
		rescue
			@category = nil
		end
	end
	
	def id
		@id
	end

	def subject
		@subject
	end

	def status
		@status_id
	end

	def priority
		@priority_id
	end

	def tracker
		@tracker_id
	end

	def start_date
		@start_date
	end

	def due_date
		@due_date
	end

	def description
		@description
	end

	def fixed_version
		@fixed_version
	end

	def parent
		@parent
	end

	def done_ratio
		@done_ratio
	end

	def category
		@category
	end

	def custom_fields_json
		@custom_fields_json
	end

	def custom_fields
		@custom_fields
	end

end