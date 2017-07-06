require 'sanitize'

module SinatraApp
  class ContentFragment < ActiveRecord::Base
    default_scope { order("locale ASC, book ASC, chapter ASC") }

    # TODO: i18n!
    validates :book, presence: {message: 'must be present, even when chapter is empty.'}
    validates :locale, presence: {message: 'must and should be present'}, length: {is: 2, message: 'must be in ISO 3166-1 Alpha 2 encoding.'}
    validates :chapter, uniqueness: {scope: [:locale, :book], message: 'must be unique within book and locale.'}
    validates :chapter, format: {with: /^[\d+.]*\d+$/, multiline: true, message: 'must be in a format like 2.3.4.5, etc.'}, allow_blank: true
    # TODO: check whether:
    # - new element would, given its chapter string, have a parent?
    # - element to be deleted has children that need to be deleted?
  
    def path
      ('/'+[locale, book, chapter].join('/')).chomp('/')
    end
    
    def heading_without_html
      h = Sanitize.clean(heading)
      h == '' ? book : h
    end
    
    def heading_and_text
      h = ""
      h += "<header>#{heading}</header>" unless heading.blank?
      h += "<section>#{html}</section>"  unless html.blank?
      h
    end
    
    scope :empty_chapter, -> { where(chapter: [nil, '']) }
    scope :book, ->(locale, book) { where(locale: locale, book: book).empty_chapter }
    scope :chapter, ->(locale, book, chapter) { where(locale: locale, book: book, chapter: chapter) }
  end
end
