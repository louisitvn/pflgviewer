require 'test_helper'

class DataFilesControllerTest < ActionController::TestCase
  setup do
    @data_file = data_files(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:data_files)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create data_file" do
    assert_difference('DataFile.count') do
      post :create, data_file: { description: @data_file.description, name: @data_file.name, status: @data_file.status }
    end

    assert_redirected_to data_file_path(assigns(:data_file))
  end

  test "should show data_file" do
    get :show, id: @data_file
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @data_file
    assert_response :success
  end

  test "should update data_file" do
    patch :update, id: @data_file, data_file: { description: @data_file.description, name: @data_file.name, status: @data_file.status }
    assert_redirected_to data_file_path(assigns(:data_file))
  end

  test "should destroy data_file" do
    assert_difference('DataFile.count', -1) do
      delete :destroy, id: @data_file
    end

    assert_redirected_to data_files_path
  end
end
