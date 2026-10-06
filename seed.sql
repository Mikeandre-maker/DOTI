
-- Optional demo material reward rates. The frontend can later read this table.
create table if not exists public.material_rates(
  material text primary key,
  points_per_kg integer not null check(points_per_kg>=0),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.material_rates(material,points_per_kg) values
('Plastic',5),('Aluminium cans',8),('Glass',3),('Paper/Cardboard',2),('Organic waste',1),('Mixed recyclables',3)
on conflict(material) do update set points_per_kg=excluded.points_per_kg;
