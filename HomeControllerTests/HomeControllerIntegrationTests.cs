﻿using mvc_minitwit;
using mvc_minitwit.Data;
using mvc_minitwit.Models;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Threading.Tasks;
using System.Web.Http.Results;
using Xunit;
using Xunit.Abstractions;
using Microsoft.Data.Sqlite;
using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using mvc_minitwit.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace HomeControllerTests
{
    public class HomeControllerIntegrationTests : IClassFixture<CustomWebApplicationFactory<Startup>>
    {
        private HttpClient _client;
        private CustomWebApplicationFactory<Startup> factory;
        private readonly ITestOutputHelper output;
        private User dummyUser = new User {
            username = "dummy321",
            email = "dummy@dummy",
            pw_hash = "very_secure",
            pw_hash2 = "very_secure" //pw_hash val will be hashed in the API
        };

        private readonly IServiceScope _scope;
        private readonly MvcDbContext _context;
        private readonly CookieContainer cookies = new System.Net.CookieContainer();

        public HomeControllerIntegrationTests(CustomWebApplicationFactory<Startup> factory, ITestOutputHelper output)
        {
            this.output = output;
            this.factory = factory;

            _client = factory.CreateDefaultClient();
            _scope = (factory.Services.GetRequiredService<IServiceScopeFactory>()).CreateScope();
            _context = _scope.ServiceProvider.GetRequiredService<MvcDbContext>();
            // database is now shared across tests
            _context.Database.EnsureCreated();
        }

        //to see more print: dotnet test --logger:"console;verbosity=detailed"
        //docs: https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-test

        private void PrintResp(HttpResponseMessage resp)
        {
            if (resp.StatusCode != HttpStatusCode.OK)
            {
                var result = resp.Content.ReadAsStringAsync().Result;
                output.WriteLine("Http operation unsuccessful");
                output.WriteLine(string.Format("Status: '{0}'", resp.StatusCode));
                output.WriteLine(string.Format("Reason: '{0}'", resp.ReasonPhrase));
                output.WriteLine(result);
            }
        }

        private void PrintUser()
        {
            output.WriteLine("Users:");
            foreach (User u in _context.user)
                output.WriteLine(u.username);
        }

        [Fact]
        public async Task Register_Error_HaveToEnterPW()
        {
            _client = factory.CreateClient();

            dummyUser.pw_hash = null;
            var resp = await _client.PostAsJsonAsync("/register", dummyUser);

            Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);


            dummyUser.pw_hash = "";
            var resp2 = await _client.PostAsJsonAsync("/register", dummyUser);
            //var strResp2 = await resp.Content.ReadAsStringAsync();

            Assert.Equal(HttpStatusCode.BadRequest, resp2.StatusCode);

            //doesn't work since get this back: https://tools.ietf.org/html/rfc7231#section-6.5.1
            //which is json. Have to parse it to that. Error is gen. from ApiData model
            //Assert.Equal("You have to enter a password", strResp2);
        }

        [Fact]
        public async Task Register_Error_PWsDontMatch()
        {
            
            _client = factory.CreateClient();

            dummyUser.pw_hash = "123";
            dummyUser.pw_hash2 = "321";
            var resp = await _client.PostAsJsonAsync("/register", dummyUser);

            Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);

        }

        [Fact]
        public async Task Register_Error_InvalidEmail()
        {
            _client = factory.CreateClient();

            dummyUser.email = "noatsign";
            var resp = await _client.PostAsJsonAsync("/register", dummyUser);
            var strResp = await resp.Content.ReadAsStringAsync();

            Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
            Assert.Equal("You have to enter a valid email address", strResp);

            dummyUser.email = "";
            var resp2 = await _client.PostAsJsonAsync("/register", dummyUser);
            var strResp2 = await resp.Content.ReadAsStringAsync();

            Assert.Equal(HttpStatusCode.BadRequest, resp2.StatusCode);
            Assert.Equal("You have to enter a valid email address", strResp2);
        }


        [Fact]
        public async Task Register_Error_UsernameAlreadyTaken()
        {
            _client = factory.CreateClient();

            var initResp = await _client.PostAsJsonAsync("/register", dummyUser);
            var initStrResp = await initResp.Content.ReadAsStringAsync();

            //register same user again:
            var response = await _client.PostAsJsonAsync("/register", dummyUser);
            var strResponse = await response.Content.ReadAsStringAsync();

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            //Assert.Equal("The username is already taken", strResponse);
            
        }


        [Fact]
        public async Task Register_Success()
        {
            _client = factory.CreateClient();

            dummyUser.username = "123dummy";
            var response = await _client.PostAsJsonAsync("/register", dummyUser);
           
            //Assert.Equal("User registered", stringResponse);
            response.EnsureSuccessStatusCode();
        }

        [Fact]
        public async Task Login_LogOut_Success()
        {
            _client = factory.CreateClient();
            dummyUser.username = "Login_LogOut_TestUser";
            var resp = await _client.PostAsJsonAsync("/register", dummyUser);
            resp.EnsureSuccessStatusCode();

            PrintUser();

            var loginResp = await _client.PostAsync("/api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);
            PrintUser();

            loginResp.EnsureSuccessStatusCode();
            IEnumerable<string> values;
            if (loginResp.Headers.TryGetValues("Set-Cookie", out values))       //TODO: consider removing the if. Just do assert
            {
                string cookie = values.First();
                output.WriteLine(cookie);
            }
            Assert.True(values.Any());

            var logOutResp = await _client.GetAsync("/api/Sign_Out");

            IEnumerable<string> values1;
            if (logOutResp.Headers.TryGetValues("Set-Cookie", out values1))
            {
                string cookie = values1.First();
                //output.WriteLine(cookie);
            }
            Assert.True(values1 == null);
        }

        [Fact]
        public async Task Login_InvalidEmail_Or_PW()
        {
            _client = factory.CreateClient();
            var noUserRegisteredResp = await _client.PostAsync("api/SignIn?email=NoSuch@Mail&password=totally_legit_pw", null);
            Assert.Equal(HttpStatusCode.BadRequest, noUserRegisteredResp.StatusCode);

            dummyUser.username = "Login_LogOut_InvalidPW_TestUser";
            var resp = await _client.PostAsJsonAsync("/register", dummyUser);
            resp.EnsureSuccessStatusCode();

            dummyUser.pw_hash = "incorrect_pw";     //invalid password from seed data user
            var invalidPWResp = await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);
            Assert.Equal(HttpStatusCode.BadRequest, invalidPWResp.StatusCode);

            dummyUser.email = "not" + dummyUser.email;      //invalid email
            var invalidEmailResp = await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);
            Assert.Equal(HttpStatusCode.BadRequest, invalidEmailResp.StatusCode);

        }

        //TODO: neg. test for missing email or pw?

        [Fact]
        public async Task CreateMessageByUser_Success()
        {
            dummyUser.username = "Message_Recording_Success_TestUser";
            var resp = await _client.PostAsJsonAsync("/register", dummyUser);
            resp.EnsureSuccessStatusCode();
            var loginResp = await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);
            loginResp.EnsureSuccessStatusCode();

            var testMess = "content for test message";
            var postMessageResp = await _client.PostAsJsonAsync("/msgs/" + dummyUser.username, new CreateMessage { content = testMess });
            postMessageResp.EnsureSuccessStatusCode();
            
            Assert.Equal("Message posted", await postMessageResp.Content.ReadAsStringAsync());
            Assert.Equal(testMess, _context.message.Where(m => m.text == testMess).Single().text);

            testMess = "";
            var postMessageResp2 = await _client.PostAsJsonAsync("/msgs/" + dummyUser.username, new CreateMessage { content = testMess });
            postMessageResp.EnsureSuccessStatusCode();
            
            Assert.Equal("Message posted", await postMessageResp.Content.ReadAsStringAsync());
            Assert.Equal(testMess, _context.message.Where(m => m.text == testMess).Single().text);

        }

        [Fact]
        public async Task CreateMessageByUser_UserNotExist()
        {

        }

        [Fact]
        public async Task Message_By_Other_User_Found_On_Public_Timeline()
        {
            dummyUser.username = "Message_By_Other_User_Found_On_Timeline_TestUser";
            await _client.PostAsJsonAsync("/register", dummyUser);
            await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);

            var testMess1 = "1st user message";
            await _client.PostAsJsonAsync("/msgs/" + dummyUser.username, new CreateMessage { content = testMess1 });
            await _client.GetAsync("/api/Sign_Out");

            dummyUser.username = "2Message_By_Other_User_Found_On_Timeline_TestUser";
            await _client.PostAsJsonAsync("/register", dummyUser);
            await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);
            
            var testMess2 = "2nd user message";
            await _client.PostAsJsonAsync("/msgs/" + dummyUser.username, new CreateMessage { content = testMess2 });
            await _client.GetAsync("/api/Sign_Out");

            var messagesPublicTimeLineResp = await _client.GetAsync("/msgs");
            messagesPublicTimeLineResp.EnsureSuccessStatusCode();
            var messages = await messagesPublicTimeLineResp.Content.ReadAsStringAsync();

            Assert.Equal(testMess1, _context.message.Where(m => m.text == testMess1).Single().text);    //order in db is not same as in resp
            Assert.Equal(testMess2, _context.message.Where(m => m.text == testMess2).Single().text);

            var definition = new[] { new { content = "" } };
            var deserialized = JsonConvert.DeserializeAnonymousType(messages, definition);

            Assert.Contains(deserialized, e => e.content.Contains(testMess1) || e.content.Contains(testMess2));

        }

        //Doesn't make sense when you're testing the API and not the Server/HomeController
        //[Fact]
        //public async Task SignIn_User_Sould_Only_See_Own_Timeline()
        //{
        //    dummyUser.username = "SignIn_User_Sould_Only_See_Own_Timeline_TestUser";
        //    await _client.PostAsJsonAsync("/register", dummyUser);
        //    await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);
        //}

        [Fact]
        public async Task Follow_User_Shows_Their_Messages_Unfollow_Doesnt()
        {
            dummyUser.username = "Follow_User_Shows_Their_Messages";
            await _client.PostAsJsonAsync("/register", dummyUser);
            await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);

            await _client.PostAsJsonAsync("msgs/"+dummyUser.username, new CreateMessage { content = "Follow test" });
            
            var followSeedDataResp = await _client.PostAsJsonAsync("fllws/" + dummyUser.username, 
                new ApiDataFollow { follow= SeedData.user.username } );
            output.WriteLine("follow: " + await followSeedDataResp.Content.ReadAsStringAsync());

            var getFollowers = await _client.GetAsync("fllws/"+dummyUser.username);
            var getFollowersString = await getFollowers.Content.ReadAsStringAsync();
            //output.WriteLine("follwoers: " + getFollowersString);
            
            getFollowers.EnsureSuccessStatusCode();
            Assert.Contains(SeedData.user.username, getFollowersString);

            var messagesOfDummyContent = await (await _client.GetAsync("msgs/" + dummyUser.username)).Content.ReadAsStringAsync();
            //var messagesOfDummyContent = await messagesOfDummyResp.Content.ReadAsStringAsync();
            //output.WriteLine("mess by dummy: " + messagesOfDummyContent); 
            Assert.Contains(SeedData.message.text, messagesOfDummyContent);

            //Unfollowing:
            output.WriteLine("Before unf.");
            foreach (Follower f in _context.follower)
                output.WriteLine("" + f.who_id);


            var unfollowSeedDataResp = await _client.PostAsJsonAsync("fllws/" + dummyUser.username,
                    new ApiDataFollow { unfollow = SeedData.user.username });
            unfollowSeedDataResp.EnsureSuccessStatusCode();

            var unfollowStr = await unfollowSeedDataResp.Content.ReadAsStringAsync();
            output.WriteLine("UNFOLLOW: " + unfollowStr);
            Assert.Equal(dummyUser.username + " now doesn't follow " + SeedData.user.username, unfollowStr);
            
            var getFollowers2 = await _client.GetAsync("fllws/" + dummyUser.username);
            var getFollowersString2 = await getFollowers.Content.ReadAsStringAsync();

            output.WriteLine("AFTER unf.");
            foreach (Follower f in _context.follower)
                output.WriteLine("" + f.who_id);

            output.WriteLine("followers: " + getFollowersString2);
            var messagesOfDummy2 = await (await _client.GetAsync("msgs/" + dummyUser.username)).Content.ReadAsStringAsync();
            output.WriteLine("messagesOfDummy2 " + messagesOfDummy2);
            Assert.DoesNotContain(SeedData.message.text, messagesOfDummy2);

            getFollowers2.EnsureSuccessStatusCode();
            Assert.DoesNotContain(SeedData.user.username, getFollowersString2);

        }

        //TODO make test checks to not be able to follow user twice
        //TODO also can't unfollow twice

        [Fact]
        public async Task Follow_User_Twice_Fails()
        {
            dummyUser.username = "Follow_User_Twice_Fails";
            await _client.PostAsJsonAsync("/register", dummyUser);
            await _client.PostAsync("api/SignIn?email=" + dummyUser.email + "&password=" + dummyUser.pw_hash, null);

            await _client.PostAsJsonAsync("fllws/" + dummyUser.username, new ApiDataFollow { follow = SeedData.user.username });
            var followSeedDataResp = await _client.PostAsJsonAsync("fllws/" + dummyUser.username,
                new ApiDataFollow { follow = SeedData.user.username });
            output.WriteLine("follow: " + await followSeedDataResp.Content.ReadAsStringAsync());
            Assert.Equal(HttpStatusCode.BadRequest, followSeedDataResp.StatusCode);


        }


    }
}
