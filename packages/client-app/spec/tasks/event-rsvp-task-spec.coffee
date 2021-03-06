_ = require 'underscore'

{NylasAPI,
 NylasAPIRequest,
 Event,
 Actions,
 APIError,
 EventRSVPTask,
 DatabaseStore,
 DatabaseWriter,
 AccountStore} = require 'nylas-exports'

xdescribe "EventRSVPTask", ->
  beforeEach ->
    spyOn(DatabaseStore, 'find').andCallFake => Promise.resolve(@event)
    spyOn(DatabaseWriter.prototype, 'persistModel').andCallFake -> Promise.resolve()
    @myName = "Ben Tester"
    @myEmail = "tester@nylas.com"
    @event = new Event
      id: '12233AEDF5'
      accountId: TEST_ACCOUNT_ID
      title: 'Meeting with Ben Bitdiddle'
      description: ''
      location: ''
      when:
        end_time: 1408123800
        start_time: 1408120200
      start: 1408120200
      end: 1408123800
      participants: [
        {"name": "Ben Bitdiddle",
        "email": "ben@bitdiddle.com",
        "status": "yes"},
        {"name": @myName,
        "email": @myEmail,
        "status": 'noreply'}
      ]
    @task = new EventRSVPTask(@event, @myEmail, "no")

  describe "performLocal", ->
    it "should mark our status as no", ->
      @task.performLocal()
      advanceClock()
      expect(@event.participants[1].status).toBe "no"

    it "should trigger an action to persist the change", ->
      @task.performLocal()
      advanceClock()
      expect(DatabaseWriter.prototype.persistModel).toHaveBeenCalled()

  describe "performRemote", ->
    it "should make the POST request to the message endpoint", ->
      spyOn(NylasAPIRequest.prototype, 'run').andCallFake => new Promise (resolve,reject) ->
      @task.performRemote()
      options = NylasAPIRequest.prototype.run.mostRecentCall.object.options
      expect(options.path).toBe("/send-rsvp")
      expect(options.method).toBe('POST')
      expect(options.accountId).toBe(@event.accountId)
      expect(options.body.event_id).toBe(@event.id)
      expect(options.body.status).toBe("no")

  describe "when the remote API request fails", ->
    beforeEach ->
      spyOn(NylasAPIRequest.prototype, 'run').andCallFake -> Promise.reject(new APIError(body: '', statusCode: 400))

    it "should not be marked with the status", ->
      @event = new Event
        id: '12233AEDF5'
        title: 'Meeting with Ben Bitdiddle'
        description: ''
        location: ''
        when:
          end_time: 1408123800
          start_time: 1408120200
        start: 1408120200
        end: 1408123800
        participants: [
          {"name": "Ben Bitdiddle",
          "email": "ben@bitdiddle.com",
          "status": "yes"},
          {"name": @myName,
          "email": @myEmail,
          "status": 'noreply'}
        ]
      @task = new EventRSVPTask(@event, @myEmail, "no")
      @task.performLocal()
      @task.performRemote()
      advanceClock()
      expect(@event.participants[1].status).toBe "noreply"

    it "should trigger an action to persist the change", ->
      @task.performLocal()
      @task.performRemote()
      advanceClock()
      expect(DatabaseWriter.prototype.persistModel).toHaveBeenCalled()
