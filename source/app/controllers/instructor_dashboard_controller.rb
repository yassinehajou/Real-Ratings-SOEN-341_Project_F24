class InstructorDashboardController < ApplicationController
  before_action :set_instructor, only: [:index, :teams, :results, :settings]  
  before_action :authenticate_user!
  before_action :ensure_instructor_role
  before_action :set_selected_course, only: [:index, :teams, :results, :settings]

  def index
    load_instructor_teams
    load_instructor_evaluations
    load_all_ratings

    respond_to do |format|
      format.html { render :index } # This will render app/views/instructor_dashboard/index.html.erb
      format.json { render json: { teams: @teams, completed_evaluations: @completed_evaluations, pending_evaluations: @pending_evaluations, avg_overall_ratings: @avg_overall_ratings, all_ratings: @all_ratings } }
    end
  end

  def teams
    load_instructor_teams
    @available_students = User
      .left_outer_joins(:teams)
      .where(role: "student")
      .group('users.id')
      .having('COUNT(teams.id) = 0')

    respond_to do |format|
      format.html {render :teams} # Render teams view
      format.json { render json: { teams: @teams, available_students: @available_students } }
    end
  end

  def results
    @results = Evaluation.joins(student: { team: :instructor }).where(status: 'completed')

    respond_to do |format|
      format.html {render :results} # Render results view
      format.json { render json: @results }
    end
  end

  def settings
    # Refactor to use settings view
    # This is a placeholder for future settings functionality
    respond_to do |format|
      format.html { render :settings }
      format.json { render json: { instructor: @instructor, selected_course: @selected_course } }
    end
  end

  private

  def set_selected_course
    if params[:course_id]
      @selected_course = current_user.courses_taught.find_by(id: params[:course_id])
    end
  
    @selected_course ||= current_user.courses_taught.first
  
    unless @selected_course
      flash[:alert] = "No courses available for selection."
      redirect_to root_path # Or another appropriate path
    end
  end

  def load_instructor_teams
    @teams = Team.where(project_id: Project.where(course_id: @selected_course.id))
  end

  def load_instructor_evaluations
    instructor_projects = Project.where(course_id: @selected_course.id)
    instructor_evaluations = Evaluation.where(project_id: instructor_projects.pluck(:id))

    @completed_evaluations = instructor_evaluations.where(status: "completed")
    @pending_evaluations = instructor_evaluations.where(status: "pending")
  end

  def load_all_instructor_ratings
    @avg_overall_ratings = {
      conceptual_rating: average_rating(:conceptual),
      practical_rating: average_rating(:practical),
      cooperation_rating: average_rating(:cooperation),
      work_ethic_rating: average_rating(:work_ethic)
    }

    @all_ratings = load_all_ratings
  end

  def ensure_instructor_role
    unless current_user.instructor?
      flash[:alert] = "Access denied. Instructors only."
      redirect_to root_path # Or another appropriate path
    end
  end

  def set_instructor
    @instructor = current_user if current_user.instructor?
  end

  def average_rating(category)
    # Restrict average ratings to the selected course
    @instructor.teams.joins(:project)
              .where(projects: { course_id: @selected_course.id })
              .joins(students: :evaluations_as_evaluatee)
              .average("evaluations.#{category}_rating")
  end

  def load_all_ratings
    # Only get ratings for the selected course's teams
    teams_ratings = {}
    team_ratings = @instructor.teams
                              .joins(:project)
                              .where(projects: { course_id: @selected_course.id })
                              .joins(:evaluations)
                              .group('teams.id', 'teams.name')
                              .select(
                                'teams.name',
                                'AVG(evaluations.conceptual_rating) AS conceptual_avg',
                                'AVG(evaluations.practical_rating) AS practical_avg',
                                'AVG(evaluations.cooperation_rating) AS cooperation_avg',
                                'AVG(evaluations.work_ethic_rating) AS work_ethic_avg'
                              )

    team_ratings.each do |team_rating|
      teams_ratings[team_rating.name] = {
        ratings: {
          conceptual_rating: team_rating.conceptual_avg,
          practical_rating: team_rating.practical_avg,
          cooperation_rating: team_rating.cooperation_avg,
          work_ethic_rating: team_rating.work_ethic_avg
        }
      }
    end
    teams_ratings
  end  
end
