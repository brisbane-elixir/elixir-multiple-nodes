defmodule MultiNode.PageController do
  use MultiNode.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
