#
# Copyright (C) 2015 - present Instructure, Inc.
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
#
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GradeSummaryAssignmentPresenter do
  before :each do
    attachment_model
    course_factory(active_all: true)
    student_in_course active_all: true
    teacher_in_course active_all: true
    @assignment = @course.assignments.create!(title: "some assignment",
                                                assignment_group: @group,
                                                points_possible: 12,
                                                tool_settings_tool: @tool)
    @attachment.context = @student
    @attachment.save!
    @submission = @assignment.submit_homework(@student, attachments: [@attachment])
  end

  let(:summary) {
    GradeSummaryPresenter.new :first, :second, :third
  }

  let(:presenter) {
    GradeSummaryAssignmentPresenter.new(summary,
                                        @student,
                                        @assignment,
                                        @submission)
  }

  describe '#is_plagiarism_attachment?' do
    it 'returns true if the attachment has an OriginalityReport' do
      OriginalityReport.create(originality_score: 0.8,
                               attachment: @attachment,
                               submission: @submission,
                               workflow_state: 'pending')

      expect(presenter.is_plagiarism_attachment?(@attachment)).to be_truthy
    end
  end

  describe '#originality_report' do
    it 'returns true when an originality report exists' do
      OriginalityReport.create(originality_score: 0.8,
                               attachment: @attachment,
                               submission: @submission,
                               workflow_state: 'pending')
      expect(presenter.originality_report?).to be_truthy
    end

    it 'returns false if no originailty report exists' do
      expect(presenter.originality_report?).not_to be_truthy
    end
  end

  describe "#grade_distribution" do
    context "when a summary's assignment_stats is empty" do
      before { summary.stubs(:assignment_stats).returns({}) }

      it "does not raise an error " do
        expect { presenter.grade_distribution }.to_not raise_error
      end

      it "returns nil when a summary's assignment_stats is empty" do
        expect(presenter.grade_distribution).to be_nil
      end
    end
  end

  describe "#original_points" do
    it "returns an empty string when assignment is muted" do
      @assignment.muted = true
      expect(presenter.original_points).to eq ''
    end

    it "returns an empty string when submission is nil" do
      test_presenter = GradeSummaryAssignmentPresenter.new(summary, @student, @assignment, nil)
      expect(test_presenter.original_points).to eq ''
    end

    it "returns the published score" do
      expect(presenter.original_points).to eq @submission.published_score
    end
  end

  describe '#deduction_present?' do
    it 'returns true when submission has positive points_deducted' do
      @submission.stubs(:points_deducted).returns(10)
      expect(presenter.deduction_present?).to eq(true)
    end

    it 'returns false when submission has zero points_deducted' do
      @submission.stubs(:points_deducted).returns(0)
      expect(presenter.deduction_present?).to eq(false)
    end

    it 'returns false when submission has nil points_deducted' do
      @submission.stubs(:points_deducted).returns(nil)
      expect(presenter.deduction_present?).to eq(false)
    end

    it 'returns false when submission is not present' do
      presenter.stubs(:submission).returns(nil)
      expect(presenter.deduction_present?).to eq(false)
    end
  end

  describe '#entered_grade' do
    it 'returns empty string when neither letter graded nor gpa scaled' do
      @assignment.update(grading_type: 'points')
      expect(presenter.entered_grade).to eq('')
    end

    it 'returns empty string when ungraded' do
      @submission.update(grade: nil)
      expect(presenter.entered_grade).to eq('')
    end

    it 'returns entered grade in parentheses' do
      @assignment.update(grading_type: 'letter_grade')
      @submission.update(grade: 'A', score: 12)

      expect(presenter.entered_grade).to eq('(A)')
    end
  end

  describe "#missing?" do
    it "returns the value of the submission method" do
      expect(@submission).to receive(:missing?).and_return('foo')
      expect(presenter.missing?).to eq('foo')
    end
  end

  describe "#late?" do
    it "returns the value of the submission method" do
      expect(@submission).to receive(:late?).and_return('foo')
      expect(presenter.late?).to eq('foo')
    end
  end
end
