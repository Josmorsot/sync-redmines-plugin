class CustomFieldsForm
	def initialize(json_custom_field)
		@name = json_custom_field["name"]
		@value = json_custom_field["value"]
		@id = json_custom_field["id"]
	end
	def name
		@name
	end
	def value
		@value
	end
	def id
		@id
	end
end