class DocumentsController < ApplicationController
  before_action :authenticate_user!, only: [:edit, :update]

  def edit
    @document = Document.find(params[:id])
  end

  def update
    @document = Document.find(params[:id])
    @document.assign_attributes(document_params)
    if @document.valid?
      @document.save!
      redirect_to root_path
    else
      redirect_to edit_document_path(@document)
    end
  end

  private

  def document_params
    prepare_update_params(
      params.require(:document).permit(:name, :ref_type, :publication_date, :excerpt)
    )
  end
end
