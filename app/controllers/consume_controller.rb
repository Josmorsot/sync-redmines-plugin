class ConsumeController < ApplicationController
  unloadable

  # Cargamos los datos básicos del REDMINE remoto
  BASE_URL="http://hgp.sandetel.es/"
  BASIC_AUTHORIZATION = "Basic bW9oZXJyZXJhLnNhZGllbDptb2hlcnJlcmEuc2FkaWVsMDk="

  def index
    find_issue_statuses
  	res=find_projects
   
    #res.each do |project|
    #  create_fixed_version project.identifier
    #end

    res.each do |project|
      save_issues project
    end
  	@projects = "LISTO"
  end

  #Busca y crea/actualiza los proyectos
  def find_projects
  	uri = URI(BASE_URL+"projects.json?limit=100")
  	req = Net::HTTP::Get.new(uri)
  	req['Authorization']=BASIC_AUTHORIZATION
  	res = Net::HTTP.start(uri.hostname, uri.port) {|http|
  	  http.request(req)
  	}

  	projects_full_json = JSON.parse(res.body)["projects"]
  	res = []
  	projects_full_json.each do |json_project|
  		p = ProjectForm.new(json_project)
  		res << p
  	end

  	res.each do |project|
      #Recorremos los proyectos, si no existen los creamos, en otro caso los actualizamos.
      project_db = Project.find_or_create_by(:identifier=>project.identifier)

      project_db.update(
                     :name => project.name,
                     :description => project.description,
                     :identifier => project.identifier,
                     :trackers=>[]
                     );

      correspond = Correspond.where(:id_remote=>project.id,:remote_type=>0).first_or_create
      correspond.id_local=project_db.id
      correspond.remote_type=0
      correspond.save

      if(!project_db.errors.empty?)
        puts project_db.errors.full_messages
      end
    end
    return res
  end


  # Busca todos los posibles estados que podrá tomar una Issue
  def find_issue_statuses
    uri = URI(BASE_URL+"issue_statuses.json")
    req = Net::HTTP::Get.new(uri)
    req['Authorization']=BASIC_AUTHORIZATION
    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(req)
    }

    issue_statuses_full_json = JSON.parse(res.body)["issue_statuses"] 
    issue_statuses_full_json.each do |json_status|
      status = IssueStatus.create(:name=>json_status["name"], 
        :is_closed=>json_status["is_closed"]!=nil)

      status.save
      if (status.errors.empty?)
        puts "Saving status:"+status.name
      else
        puts "Saving status: "+status.name+" with errors: "+status.errors.full_messages.to_s
      end
    end
  end

  #
  def find_issues(project_id,offset=0, status_id="open")
    uri = URI(BASE_URL+"issues.json?limit=100&project_id="+project_id+"&offset=#{offset}&sort=created_on&status_id=#{status_id}")
    req = Net::HTTP::Get.new(uri)
    req['Authorization']=BASIC_AUTHORIZATION
    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(req)
    }
    begin
      issues_full_json = JSON.parse(res.body)["issues"]
    rescue
      puts "ERROR: "+BASE_URL+"issues.json?limit=1&project_id="+project_id
      return []
    end
    results = []
    issues_full_json.each do |json_issue|
      p = IssueForm.new(json_issue)
      if p.custom_fields_json!=nil
        p.custom_fields_json.each do |custom_field_json|
          p.custom_fields<<CustomFieldsForm.new(custom_field_json)
        end
      end
      results << p
    end
   
    if((JSON.parse(res.body)["total_count"].to_i-offset)>100)
        results += find_issues(project_id,offset+100)
    end
    return results
  end

  def create_custom_fields(issue, issue_db)
    issue.custom_fields.each do |cf|
      correspond = Correspond.where(:id_remote=>cf.id, :remote_type=>2).first_or_create
      issueCustomField = IssueCustomField.find_or_create_by(:id=>correspond.id_local)
      issueCustomField.name = cf.name
      issueCustomField.field_format="string"
      issueCustomField.save
      begin
        if !issueCustomField.projects.include? issue_db.project
          issueCustomField.projects<<issue_db.project
        end
      rescue
        
      end

      begin
        if !issueCustomField.trackers.include? issue_db.project.trackers
          issueCustomField.trackers<<issue_db.project.trackers
        end
      rescue
        
      end

      correspond.id_local=issueCustomField.id
      correspond.remote_type=2
      correspond.save
      cvalue = CustomValue.new
      cvalue.custom_field=issueCustomField
      cvalue.value=cf.value.to_s
      issue_db.custom_field_values<<cvalue
      issue_db.save
    end  
  end

  def create_fixed_version(project_id)
    uri = URI(BASE_URL+"projects/#{project_id}/versions.json")
    puts BASE_URL+"projects/#{project_id}/versions.json"
    req = Net::HTTP::Get.new(uri)
    req['Authorization']=BASIC_AUTHORIZATION
    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(req)
    }
    begin
      versions_json=JSON.parse(res.body)["versions"];
    rescue
      puts "Response was empty"
      return nil
    end
    versions_json.each do |version_json|

      id_remote=version_json["id"].to_i
      status=version_json["status"]
      name = version_json["name"]
      description = version_json["description"]


      correspond=Correspond.where(:id_remote=>id_remote,:remote_type=>3).first_or_create
      v_fixed = Version.find_or_create_by(:id=>correspond.id_local)
      v_fixed.name=name
      v_fixed.description=description
      v_fixed.status=status
      v_fixed.project=Project.find_by(:identifier=>project_id)
      v_fixed.save
      if v_fixed.errors.empty?
        correspond.id_local=v_fixed.id
        correspond.remote_type=3
        correspond.save
      else
        puts v_fixed.errors.full_messages
      end
    end
  end

  def find_time_entries(issue_id_remote)
    uri = URI(BASE_URL+"time_entries.json?issue_id=#{issue_id_remote}")
    puts BASE_URL+"time_entries.json?issue_id=#{issue_id_remote}"
    req = Net::HTTP::Get.new(uri)
    req['Authorization']=BASIC_AUTHORIZATION
    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(req)
    }
    begin
      time_entries_activities=JSON.parse(res.body)["time_entries"];
    rescue

    end
    if time_entries_activities==nil
      time_entries_activities=[]
    end
    time_entries_activities.each do |time_entry|
      activity = time_entry["activity"]["name"]
      tea = TimeEntryActivity.find_by(:name=>activity)
      if tea == nil
        tea = TimeEntryActivity.create(:name=>activity)
        tea.save
        puts tea.errors.full_messages
      end
    end
  end

  def save_issues(project)
  	#Buscamos las issues dentro del proyecto (cerradas y abiertas)
    puts "*---->  FINDING ISSUES FROM PROJECT:"+project.identifier
    issues = find_issues project.identifier
    issues += find_issues project.identifier,0,"closed"
    parents_na=Hash.new
    project_db=Project.find_by(:identifier=>project.identifier)
    issues.each do |issue|
      #Recorremos las issues y les añadimos todos los campos necesarios
      puts "*--------->  FINDING ISSUE WITH SUBJECT:"+issue.subject
      correspond = Correspond.where(:id_remote=>issue.id, :remote_type=>1).first_or_create
      puts "ID_REMOTE = #{issue.id} <==> ID_LOCAL = #{correspond.id_local}"
      issue_db=Issue.find_or_initialize_by(:id=>correspond.id_local)
      issue_db.subject=issue.subject
      issue_db.description=issue.description
      issue_db.status=IssueStatus.find_by(:name=>issue.status)
      issue_db.project=project_db
      issue_db.start_date = issue.start_date!="" ? Time.parse(issue.start_date).strftime('%Y-%m-%d') : nil
      issue_db.due_date = issue.due_date!="" ? Time.parse(issue.due_date).strftime('%Y-%m-%d') : nil
      issue_db.done_ratio = issue.done_ratio
      issue_db.author=User.current
      issue_db.priority=IssuePriority.find_or_create_by(:name=>issue.priority) do |priority|
        priority.save
      end

      tracker_db = Tracker.find_or_create_by(:name=>issue.tracker)
      tracker_db.default_status = IssueStatus.find(1)
      begin
        if !project_db.trackers.include? tracker_db
          project_db.trackers<<tracker_db
        end
      rescue

      end
      issue_db.tracker=tracker_db
      if (issue.category!=nil)
        category=IssueCategory.find_or_create_by(:name=>issue.category)
        category.assigned_to=User.current
        puts "*-----------------> CATEGORY: #{category.name}"
        category.project=project_db
        category.save
        issue_db.category=category
        if (!category.errors.empty?)
          puts "ERROR: "+category.errors.full_messages.to_s
        end
      end

      issue_db.save
      if issue.fixed_version!=nil
        id_local_version=Correspond.where(:id_remote=>issue.fixed_version, :remote_type=>3).first.id_local
        version = Version.find_by(:id=>id_local_version)
        issue_db.fixed_version = version
        puts "VERSION #{id_local_version} <==> #{issue.fixed_version} PROJECT #{issue_db.project.id} HAS BEEN ADDED: #{version.name}" 
        issue_db.save
      end
      puts issue_db.errors.full_messages

      #Una vez que guardamos el Issue, podemos recuperar su id local y añadirlo a la tabla Corresponds para ver
      #la correspondencia entr el id_local y el remoto
      correspond.id_local=issue_db.id
      correspond.remote_type=1
      correspond.save

      # Miramos si ya tenemos a su padre. Si aún no conocemos al padre, entonces los guardamos en un Hash y cuando no queden Issues 
      # por guardar, los enlazamos
      id_parent_local = Correspond.where(:id_remote=>issue.parent.to_i, :remote_type=>1).first
      if (id_parent_local!=nil)
        issue_db.update(:parent=>Issue.find(id_parent_local.id_local))
      else
        puts "NOT FOUND YET PARENT FOR #{issue_db.id}"
        parents_na[issue_db.id]=issue.parent.to_i
      end
      
    end
    # FIN DEL BUCLE DE ISSUES

    parents_na.keys.each do |issue|
      issue_db=Issue.find(issue)
      id_parent_local = Correspond.where(:id_remote=>parents_na[issue], :remote_type=>1).first
      if (id_parent_local!=nil)
        issue_db.parent=Issue.find(id_parent_local.id_local)
        issue_db.save
      end
    end
  end
end
