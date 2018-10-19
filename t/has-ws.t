#!perl6

grammar G does Grammar::PrettyErrors {
  rule TOP {
    a b
  }
  token ws {
   <!ww> \s*
  }
}


