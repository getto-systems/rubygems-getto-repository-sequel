# getto-repository-sequel

[rubygems: getto-repository-sequel](https://rubygems.org/gems/getto-repository-sequel)

Repository helper for [Sequel](http://sequel.jeremyevans.net/)

```ruby
require "getto/repository/sequel"

class Repository < Getto::Repository::Sequel
  def account_exists?(id)
    not db[:accounts].where(id: id).empty?
  end
end

require "sequel"

db = Sequep.connect config

repository = Repository.new(db)
repository.account_exists?
```

- misc: search helper

```ruby
require "getto/repository/sequel/search"


search = Getto::Repository::Search::Sequel.new(
  limit: 1000,
  sort:  {
    column: :active,
    order:  true,
  },
  query: {
    "id.eq":     "1",

    "name.cont": "cont",

    "name.cont_as_kana": "かな",
    "name.cont_as_hira": "カナ",

    "name.cont_any": "カナ",

    "active.in": ["True"],
  },
)

where = search.where do |w|
  w.search "id.eq", &w.eq(::Sequel[:accounts][:id])

  w.search "name.cont", &w.cont(::Sequel[:accounts][:name])

  w.search "name.cont_as_kana", &w.cont_as_kana(::Sequel[:accounts][:name])
  w.search "name.cont_as_hira", &w.cont_as_hira(::Sequel[:accounts][:name])

  w.search "name.cont_any", &w.or([
    w.cont_hira_or_kana(::Sequel[:accounts][:name]),
    w.cont_hira_or_kana(::Sequel[:accounts][:kana]),
  ])

  w.search "active.in", &w.in(
    &w.is_not_null(
      ::Sequel[:account_actives][:account_id],
      "True"  => true,
      "False" => false,
    )
  )
end

order = search.order do |o|
  o.order :active, o.is_not_null(::Sequel[:account_actives][:account_id], 0, 1)

  o.order :id, ::Sequel[:accounts][:id]

  o.force ::Sequel[:accounts][:id]
end

pages = search.pages(
  db[:accounts]
    .left_join(:account_actives, account_id: :id)
    .where(where)
    .count
)
# => current page: e.g. count = 120, limit = 100 => pages = 2

db[:accounts]
  .left_join(:account_actives, account_id: :id)
  .where(where)
  .order(*order)
  .select(
    ::Sequel[:accounts][:id],
    ::Sequel[:account_actives][:account_id].as(:active),
    ::Sequel[:accounts][:name],
    ::Sequel[:accounts][:kana],
  )
  .all
```

It generates sql like below

```sql
SELECT
  `accounts`.`id`,
  `account_actives`.`account_id` as `active`,
  `accounts`.`name`,
  `accounts`.`kana`
FROM
  `accounts`
LEFT JOIN
  `account_actives`
    ON `account_actives`.`account_id` = `accounts`.`id`
WHERE
  (`accounts`.`id` = 1) AND
  (`accounts`.`name` LIKE '%cont%') AND
  (`accounts`.`name` LIKE '%かな%') AND
  (`accounts`.`name` LIKE '%カナ%') AND
  (
    (
      (`accounts`.`name` LIKE '%カナ%') OR
      (`accounts`.`name` LIKE '%かな%')
    ) OR
    (
      (`accounts`.`kana` LIKE '%カナ%') OR
      (`accounts`.`kana` LIKE '%かな%')
    )
  ) AND
  (`account_actives`.`account_id` IS NOT NULL)
ORDER BY
  if(`account_actives`.`account_id`, 0, 1) ASC,
  `accounts`.`id` ASC
```


###### Table of Contents

- [Requirements](#Requirements)
- [Usage](#Usage)
- [License](#License)

<a id="Requirements"></a>
## Requirements

- developed on ruby: 2.5.1


<a id="Usage"></a>
## Usage

### where clause

- equals

```ruby
where = search.where do |w|
  w.search "id.eq", &w.eq(::Sequel[:accounts][:id])
end
```

```sql
-- { "id.eq": "1" }
WHERE
  (`accounts`.`id` = 1)
```

- contains

```ruby
where = search.where do |w|
  w.search "name.cont", &w.cont(::Sequel[:accounts][:name])
end
```

```sql
-- { "name.cont": "cont" }
WHERE
  (`accounts`.`name` LIKE '%cont%')
```

- contains as kana

```ruby
where = search.where do |w|
  w.search "name.cont", &w.cont_as_kana(::Sequel[:accounts][:name])
end
```

```sql
-- { "name.cont": "かな" }
WHERE
  (`accounts`.`name` LIKE '%カナ%') -- convert 'かな' to 'カナ'
```

- contains as hira

```ruby
where = search.where do |w|
  w.search "name.cont", &w.cont_as_hira(::Sequel[:accounts][:name])
end
```

```sql
-- { "name.cont": "カナ" }
WHERE
  (`accounts`.`name` LIKE '%かな%') -- convert 'カナ' to 'かな'
```

- contains as hira or kana

```ruby
where = search.where do |w|
  w.search "name.cont", &w.cont_hira_or_kana(::Sequel[:accounts][:name])
end
```

```sql
-- { "name.cont": "カナ" }
WHERE
  (
    (`accounts`.`name` LIKE '%カナ%') OR
    (`accounts`.`name` LIKE '%かな%')
  )

-- { "name.cont": "かな" }
WHERE
  (
    (`accounts`.`name` LIKE '%カナ%') OR
    (`accounts`.`name` LIKE '%かな%')
  )
```

- is not null

```ruby
where = search.where do |w|
  w.search "active.is", &w.is_not_null(
    ::Sequel[:account_actives][:account_id],
    "True"  => true,
    "False" => false,
  )
end
```

```sql
-- { "active.is": "True" }
WHERE
  (`account_actives`.`account_id` IS NOT NULL)

-- { "active.is": "False" }
WHERE
  (`account_actives`.`account_id` IS NULL)
```

- or

```ruby
w.search "name.cont_any", &w.or([
  w.cont(::Sequel[:accounts][:name]),
  w.cont(::Sequel[:accounts][:kana]),
])
```

```sql
-- { "name.cont": "カナ" }
WHERE
  (
    (`accounts`.`name` LIKE '%カナ%') OR
    (`accounts`.`kana` LIKE '%カナ%')
  )
```

- in

```ruby
w.search "active.in", &w.in(
  &w.is_not_null(
    ::Sequel[:account_actives][:account_id],
    "True"  => true,
    "False" => false,
  )
)
```

```sql
-- { "active.in": ["True","False"] }
WHERE
  (
    (`account_actives`.`account_id` IS NOT NULL) OR
    (`account_actives`.`account_id` IS NULL)
  )
```

- clause by block

```ruby
w.search("active.is"){|val|
  if val == "True"
    ::Sequel.~( ::Sequel[:account_actives][:account_id] => nil )
  end
}
```

```sql
-- { "active.is": "True" }
WHERE
  (`account_actives`.`account_id` IS NOT NULL)

-- { "active.is": "False" }
WHERE
  (1 = 1) -- if block returns nil, no where-clauses
```

## Install

Add this line to your application's Gemfile:

```ruby
gem 'getto-repository-sequel'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install getto-repository-sequel
```


<a id="License"></a>
## License

getto/repository/sequel is licensed under the [MIT](LICENSE) license.

Copyright &copy; since 2018 shun@getto.systems
