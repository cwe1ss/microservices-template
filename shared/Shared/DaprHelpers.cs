using Dapr;

namespace Shared;

public static class DaprHelpers
{
    /// <summary>
    /// We must manually construct the cloud event because the .NET SDK doesn't change the default "type" (com.dapr.event.sent)
    /// </summary>
    public static CloudEvent<T> CreateCloudEvent<T>(T message)
    {
        return new CloudEvent<T>(message)
        {
            Type = nameof(T)
        };
    }
}
