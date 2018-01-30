require 'rails_helper'

feature 'Entity deletion request & review' do
  let(:user) {}
  let(:requester) { create :really_basic_user }
  let(:entity) { create :entity_person }
  let!(:deletion_request) do
    create :deletion_request, user: requester, entity: entity
  end

  before { login_as user, scope: :user }
  after { logout :user }

  def should_show_deletion_report
    report = page.find("#deletion-report")
    expect(report).to have_text "will remove the following person"
    expect(report).to have_link entity.name, href: entity_path(entity)
    expect(report).to have_text entity.description
    expect(report).to have_text "#{entity.link_count} relationships"
    expect(report).to have_text "Are you sure"
  end

  describe "requesting a deletion" do
    before do
      visit entity_path(entity)
      click_link "remove"
    end

    context "as a non-admin" do
      let(:user) { requester }

      it "shows the deletion request page" do
        successfully_visits_page new_deletion_request_path(entity_id: entity.id)
      end

      it "shows information about the entity to be deleted" do
        should_show_deletion_report
      end

      it "shows submit button" do
        expect(page).to have_button "Request Deletion"
      end

      describe "submitting request" do
        let!(:entity_count){ Entity.count }
        let!(:deletion_request_count){ DeletionRequest.count }
        let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

        before do
          allow(NotificationMailer)
            .to receive(:deletion_request_email).and_return(message_delivery)
          allow(message_delivery).to receive(:deliver_later)

          click_button "Request Deletion"
        end

        it "does not delete the entity" do
          expect(Entity.count).to eql entity_count
        end

        it "creates a pending deletion request" do
          expect(DeletionRequest.count).to eql deletion_request_count + 1
          expect(DeletionRequest.last.status).to eql 'pending'
          expect(DeletionRequest.last.user).to eql requester
          expect(DeletionRequest.last.entity).to eql entity
        end

        it "redirects to the dashboard" do
          successfully_visits_page home_dashboard_path
        end

        it "notifies admins of the request by delayed email" do
          expect(message_delivery).to have_received(:deliver_later)
          expect(NotificationMailer)
            .to have_received(:deletion_request_email).with(DeletionRequest.last)
        end
      end
    end
  end

  describe "reviewing a deltion request" do
    before { visit review_deletion_request_path(deletion_request) }

    context "as a non-admin" do
      let(:user) { create(:really_basic_user) }
      denies_access
    end

    context "as an admin" do
      let(:user) { create(:admin_user) }

      it "shows the deltion review page" do
        successfully_visits_page review_deletion_request_path(deletion_request)
      end

      it "shows a description of the request" do
        desc = page.find("#user-request-description")
        expect(desc).to have_link requester.username, "/users/#{requester.username}"
        expect(desc).to have_text "deletion was requested"
        expect(desc).to have_text LsDate.pretty_print(deletion_request.created_at)
      end

      it "shows information about the entity to be deleted" do
        should_show_deletion_report
      end

      it "shows decision buttons" do
        expect(page).to have_button "Approve"
        expect(page).to have_button "Deny"
      end

      context "making a decision" do
        before do
          expect(Entity.count).to eql 1
          expect(deletion_request.status).to eql 'pending'
        end

        context "clicking `Approve`" do
          before { click_button "Approve" }

          it "deletes the entity" do
            expect(Entity.count).to eql 0
          end

          it "records the approval" do
            expect(deletion_request.reload.status).to eql 'approved'
            expect(deletion_request.reload.reviewer).to eql user
          end

          it "redirects to the dashboard" do
            successfully_visits_page home_dashboard_path
          end
        end

        context "clicking `Deny`" do
          before { click_button "Deny" }

          it "does not delete the entity" do
            expect(Entity.count).to eql 1
          end

          it "records the denial" do
            expect(deletion_request.reload.status).to eql 'denied'
            expect(deletion_request.reload.reviewer).to eql user
          end

          it "redirects to the entity page" do
            successfully_visits_page home_dashboard_path
          end
        end
      end
    end
  end
end