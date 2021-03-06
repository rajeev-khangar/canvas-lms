#
# Copyright (C) 2017 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require_relative '../../../spec_helper'

describe Api::V1::PlannerItem do
  class PlannerItemHarness
    include Api::V1::PlannerItem

    def api_v1_users_todo_ignore_url(*args); end
    def assignment_json(*args); end
    def speed_grader_course_gradebook_url(*args); end
    def quiz_json(*args); end
    def course_quiz_url(*args); end
    def course_assignment_url(*args); end
    def wiki_page_json(*args); end
    def discussion_topic_api_json(*args); end
    def named_context_url(*args); end
  end

  before :once do
    course_factory active_all: true
    @course.root_account.enable_feature!(:student_planner)

    teacher_in_course active_all: true
    student_in_course active_all: true
    for_course = { course: @course }

    assignment_quiz [], for_course
    group_assignment_discussion for_course
    assignment_model for_course.merge(submission_types: 'online_text_entry')
    @assignment.workflow_state = "published"
    @assignment.save!

    @teacher_override = planner_override_model(plannable: @assignment, user: @teacher)
    @student_override = planner_override_model(plannable: @assignment, user: @student, marked_complete: true)
  end

  describe '.planner_item_json' do
    let(:api) { PlannerItemHarness.new }
    let(:session) { stub }

    it 'should return with a plannable_date for the respective item' do
      asg_due_at = 1.week.ago
      asg = assignment_model course: @couse, submission_types: 'online_text_entry', due_at: asg_due_at
      asg_hash = api.planner_item_json(asg, @student, session)
      expect(asg_hash[:plannable_date]).to eq asg_due_at

      dt_todo_date = 1.week.from_now
      dt = discussion_topic_model course: @couse, todo_date: dt_todo_date
      dt_hash = api.planner_item_json(dt, @student, session)
      expect(dt_hash[:plannable_date]).to eq dt_todo_date

      wiki_todo_date = 1.day.ago
      wiki = wiki_page_model course: @couse, todo_date: wiki_todo_date
      wiki_hash = api.planner_item_json(wiki, @student, session)
      expect(wiki_hash[:plannable_date]).to eq wiki_todo_date

      annc_post_date = 1.day.from_now
      annc = announcement_model context: @couse, posted_at: annc_post_date
      annc_hash = api.planner_item_json(annc, @student, session)
      expect(annc_hash[:plannable_date]).to eq annc_post_date
    end

    context 'with an existing planner override' do
      it 'should return the planner visibility state' do
        teacher_hash = api.planner_item_json(@assignment, @teacher, session)
        student_hash = api.planner_item_json(@assignment, @student, session)

        expect(teacher_hash[:visible_in_planner]).to be true
        expect(student_hash[:visible_in_planner]).to be false
      end

      it 'should return the planner override id' do
        teacher_hash = api.planner_item_json(@assignment, @teacher, session)
        student_hash = api.planner_item_json(@assignment, @student, session)

        expect(teacher_hash[:planner_override][:id]).to eq @teacher_override.id
        expect(student_hash[:planner_override][:id]).to eq @student_override.id
      end
    end

    context 'without an existing planner override' do
      it 'should return true for `visible_in_planner`' do
        json = api.planner_item_json(@quiz.assignment, @student, session)
        expect(json[:visible_in_planner]).to be true
      end

      it 'should have a nil planner_override value' do
        json = api.planner_item_json(@quiz.assignment, @student, session)
        expect(json[:planner_override]).to be_nil
      end
    end

    describe '#submission_statuses_for' do
      it 'should return the submission statuses for the learning object' do
        json = api.planner_item_json(@assignment, @student, session)
        expect(json.has_key?(:submissions)).to be true
        expect([:submitted, :excused, :graded, :late, :missing, :needs_grading, :has_feedback].all? { |k| json[:submissions].has_key?(k) }).to be true
      end

      it 'should indicate that an assignment is submitted' do
        @assignment.submit_homework(@student, body: "b")

        json = api.planner_item_json(@assignment, @student, session)
        expect(json[:submissions][:submitted]).to be true
      end

      it 'should indicate that an assignment is missing' do
        @assignment.update!(due_at: 1.week.ago)

        json = api.planner_item_json(@assignment, @student, session)
        expect(json[:submissions][:missing]).to be true
      end

      it 'should indicate that an assignment is excused' do
        submission = @assignment.submit_homework(@student, body: "b")
        submission.excused = true
        submission.save!

        json = api.planner_item_json(@assignment, @student, session)
        expect(json[:submissions][:excused]).to be true
      end

      it 'should indicate that an assignment is graded' do
        submission = @assignment.submit_homework(@student, body: "o")
        submission.update(score: 10)
        submission.grade_it!

        json = api.planner_item_json(@assignment, @student, session)
        expect(json[:submissions][:graded]).to be true
      end

      it 'should indicate that an assignment is late' do
        @assignment.update!(due_at: 1.week.ago)
        @assignment.submit_homework(@student, body: "d")

        json = api.planner_item_json(@assignment, @student, session)
        expect(json[:submissions][:late]).to be true
      end

      it 'should indicate that an assignment needs grading' do
        @assignment.submit_homework(@student, body: "y")

        json = api.planner_item_json(@assignment, @student, session)
        expect(json[:submissions][:needs_grading]).to be true
      end

      it 'should indicate that an assignment has feedback' do
        submission = @assignment.submit_homework(@student, body: "the stuff")
        submission.add_comment(user: @teacher, comment: "nice work, fam")
        submission.grade_it!

        json = api.planner_item_json(@assignment, @student, session, { start_at: 1.week.ago })
        expect(json[:submissions][:has_feedback]).to be true
      end
    end
  end
end
