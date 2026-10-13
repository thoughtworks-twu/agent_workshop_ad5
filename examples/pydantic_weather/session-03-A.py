from pydantic import BaseModel
from pydantic_ai import Agent, RunContext
from dotenv import load_dotenv

load_dotenv()

# 0. Dependency injection: Define a dependency for the city
class City(BaseModel):
    name: str
    country: str

# 1. Define your structured output using BaseModel
class WeatherResponse(BaseModel):
    city: City
    temperature: int
    metric: str = "Celsius"  # Default value for metric
    description: str    # <-- This field provides a brief description of the current weather condition.
    source: str         # <-- This field indicates the source of the weather data.
    last_updated: str   # <-- IMPORTANT: This field is helpful to know when the weather data was last updated.

# 2. Create the Agent with result_type and model_settings
agent = Agent(
    'google:gemini-3.5-flash',
    output_type=WeatherResponse, # Enforces the BaseModel output
    model_settings={'temperature': 0.3}, # Configures low temperature for strict output
    deps_type=City # Inject the City dependency into the agent
)

# 3. Use RunContext to inject dynamic context (like a user's location)
@agent.system_prompt
def add_user_context(ctx: RunContext[City]) -> str:
    return f"How is the weather in {ctx.deps.name}, {ctx.deps.country}? When and how was its latest update?"

# 4. Run the agent and pass the dependency
result = agent.run_sync("", deps=City(name="New York", country="USA"))

# The result is type-safe and perfectly structured!
# But with the introduction of the `last_updated` field, we can now also see when the weather data was updated.
print("Weather response:")
print(result.output.model_dump_json(indent=2))
