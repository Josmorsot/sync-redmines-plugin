class ConsumeController < ApplicationController
  unloadable
  BASE_URL="http://hgp.sandetel.es/"
  BASIC_AUTHORIZATION = "Basic bW9oZXJyZXJhLnNhZGllbDptb2hlcnJlcmEuc2FkaWVsMDk="
  def index
    find_issue_statuses
  	res=find_projects
    create_or_update_projects res
  	@projects = "LISTO"
  end

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
  	return res
  end

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

  def find_trackers
    uri = URI(BASE_URL+"trackers.json")
    req = Net::HTTP::Get.new(uri)
    req['Authorization']=BASIC_AUTHORIZATION
    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(req)
    }

    trackers_full_json = JSON.parse(res.body)["trackers"] 
    trackers_full_json.each do |json_tracker|
      tracker = Tracker.create(:name=>json_tracker["name"],:default_status=>IssueStatus.find(1))
      tracker.save
      if (tracker.errors.empty?)
        puts "Saving tracker:"+tracker.name
      else
        puts "Saving tracker: "+tracker.name+" with errors: "+tracker.errors.full_messages.to_s
      end
    end
  end

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
      results << p
    end
   
    if((JSON.parse(res.body)["total_count"].to_i-offset)>100)
        results += find_issues(project_id,offset+100)
    end
    return results
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
      return 1
    end
    if time_entries_activities==nil
      time_entries_activities=[]
    end
    time_entries_activities.each do |time_entry|
      activity = time_entry["activity"]["name"]
      puts "activity: "+activity
      tea = TimeEntryActivities.find_by(:name=>activity)
      if tea == nil
        puts "activity: "+activity
        tea = TimeEntryActivities.create(:name=>activity)
        tea.save
        puts tea.errors.full_messages
        return 0
      end
    end
    return 1
  end

  def create_or_update_projects(projects)
    
  	projects.each do |project|
      #Recorremos los proyectos, si no existen los creamos, en otro caso los actualizamos.
      project_db = Project.find_or_create_by(:identifier=>project.identifier)
      if project.updated_on<=project_db.updated_on
        #next
      end
      project_db.update(
                     :name => project.name,
                     :description => project.description,
                     :identifier => project.identifier,
                     :trackers=>[]
                     );

      correspond = Correspond.find_or_create_by(:id_remote=>project.id)
      correspond.id_local=project_db.id
      correspond.save

      if(project_db.errors.empty?)
        puts project_db.errors.full_messages
      end


      #Buscamos las issues dentro del proyecto (cerradas y abiertas)
      puts "*---->  FINDING ISSUES FROM PROJECT:"+project.identifier
      issues = find_issues project.identifier
      issues += find_issues project.identifier,0,"closed"
      parents_na=Hash.new

      issues.each do |issue|

        t = find_time_entries issue.id 
        if t==1
          next
        end
        #Recorremos las issues y les añadimos todos los campos necesarios
        puts "*--------->  FINDING ISSUE WITH SUBJECT:"+issue.subject
        correspond = Correspond.find_or_create_by(:id_remote=>issue.id)
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
          project_db.trackers<<tracker_db
        rescue

        end
        issue_db.tracker=tracker_db
        if (issue.category!=nil)
          category=IssueCategory.find_or_create_by(:name=>issue.category)
          category.assigned_to=User.current
          puts "*-----------------> CATEGORY: #{category.name}"
          category.project=project_db
          category.save
          if (!category.errors.empty?)
            puts "ERROR: "+category.errors.full_messages.to_s
          end
        end

        issue_db.save
        puts issue_db.errors.full_messages

        #Una vez que guardamos el Issue, podemos recuperar su id local y añadirlo a la tabla Corresponds para ver
        #la correspondencia entr el id_local y el remoto
        correspond.id_local=issue_db.id
        correspond.save

        # Miramos si ya tenemos a su padre. Si aún no conocemos al padre, entonces los guardamos en un Hash y cuando no queden Issues 
        # por guardar, los enlazamos
        id_parent_local = Correspond.find_by(:id_remote=>issue.parent.to_i)
        if (id_parent_local!=nil)
          issue_db.update(:parent=>Issue.find(id_parent_local.id_local))
        else
          parents_na[issue_db.id]=issue.parent.to_i
        end
        
      end
      # FIN DEL BUCLE DE ISSUES

      parents_na.keys.each do |issue|
        issue_db=Issue.find(issue)
        id_parent_local = Correspond.find_by(:id_remote=>parents_na[issue])
        if (id_parent_local!=nil)
          issue_db.parent=Issue.find(id_parent_local.id_local)
          issue_db.save
        end
      end



    end
  end
end
