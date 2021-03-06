module HueIterationSpec where

import Hue.Iteration
import Test.Hspec

data Msg = MyCoolMsg | ChangedMsg Int
  deriving (Show, Eq)

data State =
  State { anyNumber :: Int
        , anyString :: String }
  deriving (Show, Eq)

hueIterationSpec :: SpecWith ()
hueIterationSpec =
  describe "Given a state and a message" $ do
    let givenState = State { anyNumber = 0, anyString = "Any String"}
    let givenMsg = MyCoolMsg

    let ioOperation1 =
          return (42, "The answer")
    let ioOperation2 =
          return "Tell me why I don't like Mondays."

    let performUpdate = performIteration givenState givenMsg

    describe "Checking that the given update arguments" $
      it "should receive the given state and message" $ do
        let iteration = performUpdate $ \ currentState currentMsg ->
              if currentState == givenState && currentMsg == givenMsg
                 then return $ State 1 "ok"
              else return $ State 0 "The state or msg is not the given"
        iterationStateResult iteration `shouldBe` State 1 "ok"
    describe "Changing state" $
      describe "When I perform a change state operation" $ do
        let iteration = performUpdate $ \ currentState _ ->
              return currentState { anyString = "here" }
        it "should return a new Monad with the new state" $ do
          iterationStateResult iteration `shouldBe` State 0 "here"
          length (iterationTasksResult iteration) `shouldBe` 0
    describe "Performing an IO iteration" $ do
      describe "When I perform an IO operation" $ do
        let ioOperation =
              return (42, "The answer")
        let iteration = performUpdate $ \ currentState _ -> do
              process ioOperation $ \_ (number, text) ->
                return $ State number text
              return currentState
        it "Should register the given task" $ do
          let task = head $ iterationTasksResult iteration
          ioIterationTask <- task
          let ioIterationResult = ioIterationTask givenState
          iterationStateResult (iterationToResult ioIterationResult) `shouldBe` State 42 "The answer"
      describe "Ignoring the result" $ do
        let iteration = performUpdate $ \currentState _ -> do
              process_ (return ())
              return currentState
        it "should return the state without changes" $ do
          let task = head (iterationTasksResult iteration)
          ioIterationTask <- task
          let ioIterationResult = ioIterationTask givenState
          iterationStateResult (iterationToResult ioIterationResult) `shouldBe` State 0 "Any String"
      describe "Given many IO operations" $ do
        let iteration = performUpdate $ \currentState _ -> do
              process ioOperation1 $ \_ (number, text) ->
                return $ State number text
              _ <- return "any thing that between the tasks"
              process ioOperation2 $ \_ text ->
                return $ State (-1) text
              return currentState
        it "Should register the given tasks" $ do
          task1 <- head (iterationTasksResult iteration)
          task2 <- iterationTasksResult iteration !! 1
          let ioIterationResult1 = task1 givenState
          iterationStateResult (iterationToResult ioIterationResult1) `shouldBe` State 42 "The answer"
          let ioIterationResult2 = task2 givenState
          iterationStateResult (iterationToResult ioIterationResult2) `shouldBe` State (-1) "Tell me why I don't like Mondays."
      describe "When I call a task providing an state" $ do
        let ioOperation = return "The answer"
        let iteration = performUpdate $ \currentState _ -> do
              process ioOperation $ \newCurrentState _ ->
                return newCurrentState
              return currentState
        it "should receive the given state" $ do
          let task = head $ iterationTasksResult iteration
          ioIterationTask <- task
          let ioIterationResult = ioIterationTask $ State 1 "My given state"
          iterationStateResult (iterationToResult ioIterationResult) `shouldBe` State 1 "My given state"
    describe "Performing many operations" $
      describe "When I perform many and different operations" $ do
        let iteration = performUpdate $ \ _ _ -> do
              process ioOperation1 $ \_ (number, text) ->
                return $ State number text
              _ <- return "any thing that between the tasks"
              process ioOperation2 $ \_ text ->
                return $ State (-1) text
              return $ State 31 "All done"
        it "Should register all tasks and responses correctly" $ do
          length (iterationTasksResult iteration) `shouldBe` 2
          iterationStateResult iteration `shouldBe` State 31 "All done"
    describe "Using the HueIteration as a Applicative" $
      describe "When I do a sequence application" $ do
        describe "And it's a identity application" $ do
          let (Iteration tasks result) =
                pure id <*> Iteration [] "Hi"

          it "should return the same result and the data constructor should be HueIteration" $ do
            result `shouldBe` "Hi"
            length tasks `shouldBe` 0
        describe "And both has iteration tasks" $ do
          let functionIteration = do
                process ioOperation1 $ \state _ -> return state
                process ioOperation1 $ \state _ -> return state
                return id
          let anotherIteration = do
                process ioOperation1 $ \state _ -> return state
                process ioOperation1 $ \state _ -> return state
                return $ State 42 "All fine"
          let (Iteration tasks result) = functionIteration <*> anotherIteration

          it "should return the same result with both iteration data" $ do
            result `shouldBe` State 42 "All fine"
            length tasks `shouldBe` 4
        describe "Add a iteration with tasks and a finished iteration" $ do
          let functionIteration = do
                process ioOperation1 $ \state _ -> return state
                process ioOperation1 $ \state _ -> return state
                return $ \result -> result ++ " that's wrong"

          it "should return a finished iteration with the finished state" $ do
            let (FinishedIteration state) =
                  functionIteration <*> FinishedIteration "That's right!"
            state `shouldBe` "That's right!"
        describe "Add a finished iteration to another iteration" $ do
          let anotherIteration = do
                process ioOperation1 $ \state _ -> return state
                process ioOperation1 $ \state _ -> return state
                return $ State (-1) "Error"

          let FinishedIteration state =
                FinishedIteration (State 42 "OK") <*> anotherIteration

          it "should return the finished data and ignore the another iteration" $
            state `shouldBe` State 42 "OK"
    describe "Finishing an iteration" $
      describe "When I finish an iteration" $
        describe "And perform any io iteration" $ do
          let iteration = performUpdate $ \_ _ -> do
                process ioOperation1 $ \state _ -> return state
                _ <- finish $ State 42 "Nice!"
                process ioOperation1 $ \state _ -> return state
                return $ State 20 "Not nice!"
          it "should ignore the IO operations and assume the given state" $ do
            length (iterationTasksResult iteration) `shouldBe` 0
            iterationStateResult iteration `shouldBe` State 42 "Nice!"
