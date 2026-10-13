import os
import requests
from dotenv import load_dotenv
from pydantic import BaseModel
from pydantic_ai import Agent, RunContext

load_dotenv()  # Load environment variables from .env file
WEATHER_API_URL = os.getenv("WEATHER_API_URL")
weather_api_key = os.getenv("WEATHER_API_KEY")

# 0. Dependency injection: Define a dependency for the city
class City(BaseModel):
    name: str
    country: str

# 1. Define your structured output using BaseModel
class WeatherResponse(BaseModel):
    city: City
    temperature: int
    metric: str = "Celsius"  # Default value for metric
    description: str  # <-- This field provides a brief description of the current weather condition.
    source: str
    last_updated: str  # <-- IMPORTANT: This field is helpful to know when the weather data was last updated.

# 2. Create the Agent with result_type and model_settings
agent = Agent(
    'google:gemini-3.5-flash',
    deps_type=City, # Inject the City dependency into the agent
    output_type=WeatherResponse, # Enforces the BaseModel output
    model_settings={'temperature': 0.3}, # Configures low temperature for strict output
)

# 3. Use RunContext to inject dynamic context (like a user's location)
@agent.system_prompt
def add_user_context(ctx: RunContext[City]) -> str:
    return f"How is the weather in {ctx.deps.name}, {ctx.deps.country}? When and how was its latest update?"

# 4. Define a tool to fetch live weather data from WeatherAPI.com
# This is the Dynamic Context Injection (DCI) part, where we fetch live data and inject it into the model's context.
@agent.tool
def get_weather(ctx: RunContext[City]):
    """Current weather from WeatherAPI.com, for the city given in deps."""
    city = ctx.deps.name
    country = ctx.deps.country
    query = f"{city},{country}"


    response = requests.get(
        WEATHER_API_URL,
        # The key travels as a parameter, so it never lands in the log above.
        params={"key": weather_api_key, "q": query},
        timeout=10,
    )
    response.raise_for_status()
    data = response.json()

    # The live data, on its way back into the model's context.
    return {
        "city": data["location"]["name"],
        "country": data["location"]["country"],
        "temperature": data["current"]["temp_c"],
        "metric": "Celsius",
        "description": data["current"]["condition"]["text"],
        "last_updated": data["current"]["last_updated"],
    }

# 5. Run the agent and pass the dependency
result = agent.run_sync("", deps=City(name="New York", country="USA"))

# The result is type-safe and perfectly structured!
# But with the introduction of the `last_updated` field, we can now also see when the weather data was updated.
print("Weather response:")
print(result.output.model_dump_json(indent=2))
