using Grpc.Core;

namespace InternalGrpc.Api;

public class InternalGrpcServiceImpl : InternalGrpcService.InternalGrpcServiceBase
{
    private static readonly List<InternalGrpcEntityDto> Entities = new();

    public override Task<ListEntitiesResponse> ListEntities(ListEntitiesRequest request, ServerCallContext context)
    {
        return Task.FromResult(new ListEntitiesResponse
        {
            Entities = { Entities },
        });
    }

    public override Task<InternalGrpcEntityDto> CreateEntity(CreateEntityRequest request, ServerCallContext context)
    {
        if (request.Entity is null)
            throw new RpcException(new Status(StatusCode.InvalidArgument, "'entity' is missing"));

        if (!string.IsNullOrWhiteSpace(request.Entity.EntityId) && Entities.Any(x => x.EntityId == request.Entity.EntityId))
            throw new RpcException(new Status(StatusCode.AlreadyExists, "The given id already exists"));
        
        var entity = request.Entity.Clone();

        Entities.Add(entity);

        return Task.FromResult(entity);
    }
}
