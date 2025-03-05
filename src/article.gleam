import gleam/option.{type Option, Some, None}
import birl
import gleam/order

pub type Article {
  Article(
    title: String,
    link: String,
    date: Option(birl.Time),
    categories: List(String),
    description: String,
  )
}

//TODO: make it a record with the feed's own information
pub type Feed =
  List(Article)


pub fn compare(article1: Article, article2: Article) {
  case article1.date, article2.date {
    Some(d1), Some(d2) -> birl.compare(d1, d2)
    Some(_), None -> order.Gt
    None, Some(_) -> order.Lt
    None, None -> order.Gt
  }
}

pub fn to_date_str(article: Article) -> String {
  case article.date {
    None -> "at some time"
    Some(d) -> birl.to_naive(d)
  }
}
