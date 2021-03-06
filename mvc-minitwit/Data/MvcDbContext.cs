﻿using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using mvc_minitwit.Models;

namespace mvc_minitwit.Data
{
    public class MvcDbContext : DbContext
    {
        public MvcDbContext (DbContextOptions<MvcDbContext> options)
            : base(options)
        {

        }

protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder
                .Entity<Follower>(eb =>
                {
                    eb.HasKey(m => new { m.who_id, m.whom_id });
                });
            modelBuilder
                .Entity<User>().HasMany(x => x.messages).WithOne(x => x.author).HasForeignKey(x => x.author_id);
        }


        public DbSet<Message> message { get; set; }
        public DbSet<Follower> follower { get; set; }
        public DbSet<User> user { get; set; }
        public DbSet<mvc_minitwit.Models.TimelineData> TimelineData { get; set; }
    }

    
}