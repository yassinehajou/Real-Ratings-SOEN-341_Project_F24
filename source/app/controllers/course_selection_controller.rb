require 'pexels'

PexelsClient = Pexels::Client.new(ENV['PEXELS_API_KEY'])


class CourseSelectionController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.instructor?
      @courses = current_user.courses_taught
    else
      @student_courses = current_user.enrolled_courses
      @available_courses = Course.where.not(id: @student_courses.pluck(:id))
    end

    # Fetch Pexels image URLs for each course if it doesn't already exist
    (@courses || @student_courses || []).each do |course|
      course.image_url ||= fetch_image_url(course.title)
    end

    # Ensure @available_courses is always set for students
    if current_user.student?
      @available_courses ||= Course.all
    end

    # Add a flash message if there are no courses
    if (@courses.blank? && current_user.instructor?) || (@student_courses.blank? && @available_courses.blank? && current_user.student?)
      flash.now[:alert] = "No courses available. #{current_user.instructor? ? 'Create a new course to get started.' : 'Please contact your instructor.'}"
    end
  end

  def select_course
    course = Course.find(params[:course_id])
    
    # Store selected course ID in session
    session[:selected_course_id] = course.id

    # Redirect based on role
    if current_user.instructor?
      redirect_to course_instructor_dashboard_index_path(course_id: course.id) # Instructor dashboard
    else
      redirect_to course_student_dashboard_index_path(course_id: course.id) # Student dashboard
    end
  end

  def update_course_selection
    course = Course.find(params[:course_id])
    
    if current_user.enrolled_courses.count < 6 && !current_user.enrolled_courses.include?(course)
      current_user.enrolled_courses << course
      flash[:notice] = "You have successfully enrolled in #{course.code}."
    else
      flash[:alert] = "You can only enroll in up to 6 courses or you're already enrolled in this course."
    end

    redirect_to course_selection_index_path
  end

  def drop_course
    course = Course.find(params[:course_id])
    
    if current_user.enrolled_courses.include?(course)
      current_user.enrolled_courses.delete(course)
      flash[:notice] = "You have successfully dropped #{course.code}."
    else
      flash[:alert] = "You are not enrolled in this course."
    end

    redirect_to course_selection_index_path
  end

  def create
    @course = current_user.courses_taught.build(course_params)
    
    if @course.save
      flash[:notice] = "Course successfully created."
      redirect_to course_selection_index_path
    else
      flash[:alert] = "Failed to create course: #{@course.errors.full_messages.join(', ')}"
      redirect_to course_selection_index_path
    end
  end

  private

  # Add this method to whitelist course parameters
  def course_params
    params.require(:course).permit(:code, :title)
  end

  def fetch_image_url(course_title)
    begin
      search_results = PexelsClient.photos.search(course_title, per_page: 1)
      if search_results && search_results.photos.any?
        search_results.photos.first.src['medium'] # Use the medium-sized image URL
      else
        "https://via.placeholder.com/250x120?text=No+Image+Available" # Use a default placeholder image URL
      end
    rescue => e
      Rails.logger.error "Error fetching image for #{course_title}: #{e.message}"
      "https://via.placeholder.com/250x120?text=No+Image+Available" # Use a default placeholder on error
    end
  end
  
end
