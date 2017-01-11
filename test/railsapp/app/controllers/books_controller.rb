class BooksController < ApplicationController
  def create
    t 'books.create.success'
    t '.success'
    t :foo
  end
end
